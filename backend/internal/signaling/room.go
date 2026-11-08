package signaling

import (
	"encoding/json"
	"log/slog"
	"sync"

	"github.com/gorilla/websocket"
)

// Message types exchanged across WebSocket
const (
	TypeJoin       = "join"
	TypeOffer      = "offer"
	TypeAnswer     = "answer"
	TypeCandidate  = "candidate"
	TypeLeave      = "leave"
	TypePing       = "ping"
	TypePong       = "pong"
	TypePeerJoined = "peer_joined"
	TypePeerLeft   = "peer_left"
	TypeError      = "error"
)

// SignalMessage is the envelope for all signaling payloads
type SignalMessage struct {
	Type     string          `json:"type"`
	RoomID   string          `json:"room_id"`
	SenderID string          `json:"sender_id"`
	TargetID string          `json:"target_id,omitempty"`
	Role     string          `json:"role,omitempty"` // "baby" or "parent"
	Payload  json.RawMessage `json:"payload,omitempty"`
}

// Peer represents an active WebSocket client session
type Peer struct {
	ID     string
	Role   string
	RoomID string
	Conn   *websocket.Conn
	mu     sync.Mutex
}

func (p *Peer) Send(msg SignalMessage) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.Conn.WriteJSON(msg)
}

// Room represents a baby monitor session
type Room struct {
	ID    string
	Baby  *Peer
	Peers map[string]*Peer
	mu    sync.RWMutex
}

// RoomManager coordinates multi-tenant baby monitor sessions
type RoomManager struct {
	rooms map[string]*Room
	mu    sync.RWMutex
}

func NewRoomManager() *RoomManager {
	return &RoomManager{
		rooms: make(map[string]*Room),
	}
}

func (rm *RoomManager) Join(roomID string, peer *Peer) {
	rm.mu.Lock()
	room, exists := rm.rooms[roomID]
	if !exists {
		room = &Room{
			ID:    roomID,
			Peers: make(map[string]*Peer),
		}
		rm.rooms[roomID] = room
		ActiveRoomsGauge.Inc()
	}
	rm.mu.Unlock()

	room.mu.Lock()
	room.Peers[peer.ID] = peer
	if peer.Role == "baby" {
		room.Baby = peer
	}
	ActivePeersGauge.Inc()
	room.mu.Unlock()

	slog.Info("Peer joined room", "room_id", roomID, "peer_id", peer.ID, "role", peer.Role)

	// Notify other peers in the room
	room.Broadcast(SignalMessage{
		Type:     TypePeerJoined,
		RoomID:   roomID,
		SenderID: peer.ID,
		Role:     peer.Role,
	}, peer.ID)
}

func (rm *RoomManager) Leave(roomID string, peerID string) {
	rm.mu.Lock()
	room, exists := rm.rooms[roomID]
	if !exists {
		rm.mu.Unlock()
		return
	}
	rm.mu.Unlock()

	room.mu.Lock()
	peer, exists := room.Peers[peerID]
	if !exists {
		room.mu.Unlock()
		return
	}
	delete(room.Peers, peerID)
	if room.Baby != nil && room.Baby.ID == peerID {
		room.Baby = nil
	}
	ActivePeersGauge.Dec()
	empty := len(room.Peers) == 0
	room.mu.Unlock()

	slog.Info("Peer left room", "room_id", roomID, "peer_id", peerID, "role", peer.Role)

	if empty {
		rm.mu.Lock()
		delete(rm.rooms, roomID)
		ActiveRoomsGauge.Dec()
		rm.mu.Unlock()
		slog.Info("Room cleaned up", "room_id", roomID)
	} else {
		// Notify remaining peers
		room.Broadcast(SignalMessage{
			Type:     TypePeerLeft,
			RoomID:   roomID,
			SenderID: peerID,
			Role:     peer.Role,
		}, "")
	}
}

func (rm *RoomManager) Route(msg SignalMessage) {
	rm.mu.RLock()
	room, exists := rm.rooms[msg.RoomID]
	rm.mu.RUnlock()

	if !exists {
		slog.Warn("Attempted to route to non-existent room", "room_id", msg.RoomID)
		MessageErrorsCounter.Inc()
		return
	}

	MessagesCounter.WithLabelValues(msg.Type).Inc()

	room.mu.RLock()
	defer room.mu.RUnlock()

	// If a target peer is specified, unicast to that peer
	if msg.TargetID != "" {
		if target, ok := room.Peers[msg.TargetID]; ok {
			_ = target.Send(msg)
		}
		return
	}

	// Otherwise broadcast to all other peers in the room
	for id, peer := range room.Peers {
		if id != msg.SenderID {
			_ = peer.Send(msg)
		}
	}
}

func (r *Room) Broadcast(msg SignalMessage, excludeID string) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	for id, peer := range r.Peers {
		if id != excludeID {
			_ = peer.Send(msg)
		}
	}
}
