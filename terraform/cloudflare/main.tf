terraform {
  required_version = ">= 1.5.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.30"
    }
  }
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token with Zone.DNS permissions"
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Cloudflare Zone ID for charafeddine.xyz"
  type        = string
}

variable "vps_public_ip" {
  description = "Public IPv4 address of the Oracle Cloud or AWS VPS"
  type        = string
}

variable "shared_hosting_ip" {
  description = "Public IPv4 of your shared hosting server (for landing page)"
  type        = string
  default     = ""
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# 1. Landing Page & Privacy Policy Subdomain: ibnik.charafeddine.xyz
resource "cloudflare_record" "landing" {
  zone_id = var.zone_id
  name    = "ibnik"
  content = var.shared_hosting_ip != "" ? var.shared_hosting_ip : var.vps_public_ip
  type    = "A"
  proxied = true # Cloudflare CDN & DDoS protection enabled for website
  comment = "Ibnik baby monitor marketing landing page and privacy policy"
}

# 2. WebSocket Signaling Subdomain: signal.charafeddine.xyz
resource "cloudflare_record" "signaling" {
  zone_id = var.zone_id
  name    = "signal"
  content = var.vps_public_ip
  type    = "A"
  proxied = false # Direct connection for low-latency WebSockets
  comment = "Ibnik WebRTC signaling endpoint"
}

# 3. Coturn STUN/TURN Subdomain: turn.charafeddine.xyz
resource "cloudflare_record" "turn" {
  zone_id = var.zone_id
  name    = "turn"
  content = var.vps_public_ip
  type    = "A"
  proxied = false # Raw UDP/TCP must NOT be proxied through Cloudflare CDN
  comment = "Coturn STUN/TURN server for WebRTC relay"
}

# 4. Metrics & Monitoring Subdomain: metrics.ibnik.charafeddine.xyz
resource "cloudflare_record" "metrics" {
  zone_id = var.zone_id
  name    = "metrics.ibnik"
  content = var.vps_public_ip
  type    = "A"
  proxied = true # Proxied with SSL
  comment = "Grafana & Prometheus observability dashboard"
}
