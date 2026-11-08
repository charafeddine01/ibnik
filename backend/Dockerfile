# syntax=docker/dockerfile:1.4

# Step 1: Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install git and ca-certificates for fetching dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Cache dependencies
COPY go.mod go.sum* ./
RUN go mod download || true

# Copy source code
COPY . .

# Build static binary with optimizations and no debugging info
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-w -s" -o /app/bin/signaling ./cmd/signaling

# Step 2: Runtime stage using Google Distroless (Ultra-secure, no shell, non-root)
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /

# Copy binary and SSL certs from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /app/bin/signaling /signaling

# Non-root user (65532:65532)
USER nonroot:nonroot

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/signaling", "-healthcheck"] || exit 1

ENTRYPOINT ["/signaling"]
