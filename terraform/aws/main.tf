terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro" # Free tier eligible
  description = "EC2 instance type"
}

variable "ssh_key_name" {
  type        = string
  description = "Name of existing AWS EC2 Key Pair"
}

provider "aws" {
  region = var.aws_region
}

# 1. VPC & Subnet
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "baby-monitor-vpc" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "baby-monitor-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "baby-monitor-public-subnet" }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

# 2. Security Group with WebRTC & Coturn Ports
resource "aws_security_group" "webrtc_sg" {
  name        = "baby-monitor-sg"
  description = "Allow WebRTC, Coturn, and HTTPS inbound traffic"
  vpc_id      = aws_vpc.main.id

  # Inbound SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP & HTTPS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound Coturn STUN/TURN (UDP & TCP 3478, TCP 5349)
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5349
    to_port     = 5349
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound WebRTC UDP Media Relay Port Range (49152 - 65535)
  ingress {
    from_port   = 49152
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound All
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Ubuntu 24.04 LTS AMI lookup
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# 4. EC2 Instance
resource "aws_instance" "monitor_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.webrtc_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io docker-compose-v2 git
    systemctl enable --now docker
    usermod -aG docker ubuntu
  EOF

  tags = {
    Name = "baby-monitor-relay-ec2"
  }
}

output "instance_public_ip" {
  value       = aws_instance.monitor_server.public_ip
  description = "Public IP address of the AWS EC2 instance"
}
