package signaling

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	ActiveRoomsGauge = promauto.NewGauge(prometheus.GaugeOpts{
		Namespace: "babymonitor",
		Subsystem: "signaling",
		Name:      "active_rooms",
		Help:      "Total number of currently active baby monitor rooms",
	})

	ActivePeersGauge = promauto.NewGauge(prometheus.GaugeOpts{
		Namespace: "babymonitor",
		Subsystem: "signaling",
		Name:      "active_peers",
		Help:      "Total number of currently connected peer WebSocket sessions",
	})

	MessagesCounter = promauto.NewCounterVec(prometheus.CounterOpts{
		Namespace: "babymonitor",
		Subsystem: "signaling",
		Name:      "messages_total",
		Help:      "Total number of WebRTC signaling messages processed",
	}, []string{"type"})

	MessageErrorsCounter = promauto.NewCounter(prometheus.CounterOpts{
		Namespace: "babymonitor",
		Subsystem: "signaling",
		Name:      "message_errors_total",
		Help:      "Total number of errors encountered while processing signaling messages",
	})
)
