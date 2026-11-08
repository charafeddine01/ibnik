package signaling

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"fmt"
	"time"
)

// TurnCredentialResponse represents ephemeral TURN server credentials for WebRTC.
type TurnCredentialResponse struct {
	Username string   `json:"username"`
	Password string   `json:"password"`
	TTL      int      `json:"ttl"`
	URIs     []string `json:"uris"`
}

// GenerateTurnCredentials implements RFC 5766 REST API dynamic authentication.
// It generates a time-limited username and HMAC-SHA1 password matching coturn's 'use-auth-secret'.
func GenerateTurnCredentials(secret string, turnHost string, ttl time.Duration) TurnCredentialResponse {
	expiry := time.Now().Add(ttl).Unix()
	username := fmt.Sprintf("%d:babymonitor", expiry)

	h := hmac.New(sha1.New, []byte(secret))
	h.Write([]byte(username))
	password := base64.StdEncoding.EncodeToString(h.Sum(nil))

	uris := []string{
		fmt.Sprintf("stun:%s:3478", turnHost),
		fmt.Sprintf("turn:%s:3478?transport=udp", turnHost),
		fmt.Sprintf("turn:%s:3478?transport=tcp", turnHost),
		fmt.Sprintf("turns:%s:5349?transport=tcp", turnHost),
	}

	return TurnCredentialResponse{
		Username: username,
		Password: password,
		TTL:      int(ttl.Seconds()),
		URIs:     uris,
	}
}
