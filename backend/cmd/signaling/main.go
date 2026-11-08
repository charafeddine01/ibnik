package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/charafeddine/baby_monitor/backend/internal/signaling"
	"github.com/gorilla/websocket"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// Allows cross-platform mobile apps to connect
		return true
	},
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

func main() {
	// 1. Structured JSON logging
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	turnSecret := os.Getenv("TURN_SECRET")
	if turnSecret == "" {
		turnSecret = "babymonitor-dev-secret-change-in-prod"
	}

	turnHost := os.Getenv("TURN_HOST")
	if turnHost == "" {
		turnHost = "turn.charafeddine.xyz"
	}

	roomManager := signaling.NewRoomManager()

	mux := http.NewServeMux()

	// 2. Health & Readiness Probes
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"healthy"}`))
	})

	mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ready"}`))
	})

	// 3. Prometheus Metrics Endpoint
	mux.Handle("/metrics", promhttp.Handler())

	// 4. Dynamic RFC 5766 TURN credentials endpoint
	mux.HandleFunc("/api/turn-credentials", func(w http.ResponseWriter, r *http.Request) {
		creds := signaling.GenerateTurnCredentials(turnSecret, turnHost, 24*time.Hour)
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		_ = json.NewEncoder(w).Encode(creds)
	})

	// 5. WebSocket Signaling Endpoint
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			slog.Error("WebSocket upgrade failed", "error", err)
			return
		}
		defer conn.Close()

		peerID := r.URL.Query().Get("peer_id")
		roomID := r.URL.Query().Get("room_id")
		role := r.URL.Query().Get("role") // "baby" or "parent"

		if peerID == "" || roomID == "" {
			_ = conn.WriteJSON(signaling.SignalMessage{
				Type:    signaling.TypeError,
				Payload: json.RawMessage(`"peer_id and room_id required"`),
			})
			return
		}

		peer := &signaling.Peer{
			ID:     peerID,
			Role:   role,
			RoomID: roomID,
			Conn:   conn,
		}

		roomManager.Join(roomID, peer)
		defer roomManager.Leave(roomID, peerID)

		// Set connection read deadlines & ping/pong
		_ = conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		conn.SetPongHandler(func(string) error {
			_ = conn.SetReadDeadline(time.Now().Add(60 * time.Second))
			return nil
		})

		for {
			var msg signaling.SignalMessage
			err := conn.ReadJSON(&msg)
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					slog.Warn("WebSocket closed unexpectedly", "peer_id", peerID, "error", err)
				}
				break
			}

			if msg.Type == signaling.TypePing {
				_ = peer.Send(signaling.SignalMessage{Type: signaling.TypePong})
				continue
			}

			// Ensure metadata is populated
			msg.SenderID = peerID
			msg.RoomID = roomID
			roomManager.Route(msg)
		}
	})

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// 6. Graceful Shutdown
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		slog.Info("Starting Baby Monitor signaling server", "port", port, "turn_host", turnHost)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("Server listen failed", "error", err)
			os.Exit(1)
		}
	}()

	<-stop
	slog.Info("Shutting down signaling server gracefully...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		slog.Error("Server forced shutdown", "error", err)
	}

	slog.Info("Server stopped cleanly.")
}
