.PHONY: all build test lint clean docker-build docker-run run

APP_NAME := baby-monitor-signaling
DOCKER_IMAGE := ghcr.io/charafeddine/baby-monitor-signaling
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "v0.1.0")

all: test build

build:
	@echo "Building signaling binary..."
	go build -trimpath -ldflags="-w -s" -o bin/signaling ./cmd/signaling

test:
	@echo "Running backend unit tests with race detector..."
	go test -v -race -cover ./...

lint:
	@echo "Running golangci-lint..."
	golangci-lint run ./... || echo "golangci-lint not installed, skipping local check"

clean:
	@echo "Cleaning build artifacts..."
	rm -rf bin/

docker-build:
	@echo "Building Docker container image $(DOCKER_IMAGE):$(VERSION)..."
	docker build -t $(DOCKER_IMAGE):$(VERSION) -t $(DOCKER_IMAGE):latest .

docker-run:
	@echo "Running Docker container locally..."
	docker run -p 8080:8080 --env-file ../.env $(DOCKER_IMAGE):latest

run:
	@echo "Running signaling server locally..."
	go run ./cmd/signaling
