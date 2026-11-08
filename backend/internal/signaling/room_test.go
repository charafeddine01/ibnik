package signaling

import (
	"testing"
	"time"
)

func TestGenerateTurnCredentials(t *testing.T) {
	secret := "test-secret"
	host := "turn.example.com"
	ttl := 1 * time.Hour

	creds := GenerateTurnCredentials(secret, host, ttl)

	if creds.Username == "" {
		t.Fatal("expected non-empty username")
	}
	if creds.Password == "" {
		t.Fatal("expected non-empty password")
	}
	if creds.TTL != 3600 {
		t.Fatalf("expected TTL 3600, got %d", creds.TTL)
	}
	if len(creds.URIs) == 0 {
		t.Fatal("expected at least one TURN URI")
	}
}

func TestRoomManagerLifecycle(t *testing.T) {
	rm := NewRoomManager()
	roomID := "room-123"

	// Mock peer 1
	p1 := &Peer{
		ID:     "peer-baby-1",
		Role:   "baby",
		RoomID: roomID,
	}

	rm.Join(roomID, p1)

	rm.mu.RLock()
	room, exists := rm.rooms[roomID]
	rm.mu.RUnlock()

	if !exists {
		t.Fatal("expected room to exist")
	}
	if room.Baby == nil || room.Baby.ID != "peer-baby-1" {
		t.Fatal("expected baby peer to be assigned")
	}

	rm.Leave(roomID, "peer-baby-1")

	rm.mu.RLock()
	_, existsAfterLeave := rm.rooms[roomID]
	rm.mu.RUnlock()

	if existsAfterLeave {
		t.Fatal("expected empty room to be deleted automatically")
	}
}
