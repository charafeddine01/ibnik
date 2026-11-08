terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.30"
    }
  }
}

variable "tenancy_ocid" { type = string }
variable "user_ocid" { type = string }
variable "fingerprint" { type = string }
variable "private_key_path" { type = string }
variable "region" {
  type    = string
  default = "us-ashburn-1"
}
variable "compartment_ocid" { type = string }
variable "ssh_public_key" { type = string }

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# 1. Virtual Cloud Network (VCN)
resource "oci_core_vcn" "baby_monitor_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "baby-monitor-vcn"
  dns_label      = "babymonitor"
}

# 2. Internet Gateway
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  display_name   = "baby-monitor-igw"
  vcn_id         = oci_core_vcn.baby_monitor_vcn.id
  enabled        = true
}

# 3. Route Table
resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.baby_monitor_vcn.id
  display_name   = "baby-monitor-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# 4. Security List with WebRTC & Coturn Firewall Rules
resource "oci_core_security_list" "baby_monitor_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.baby_monitor_vcn.id
  display_name   = "baby-monitor-security-list"

  # Outbound: allow all
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Inbound: SSH (Port 22)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Inbound: HTTP / HTTPS (Ports 80 & 443)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Inbound: Coturn STUN/TURN (UDP 3478 & TCP 3478)
  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"
    udp_options {
      min = 3478
      max = 3478
    }
  }
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 3478
      max = 3478
    }
  }

  # Inbound: Coturn TLS (TCP 5349)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 5349
      max = 5349
    }
  }

  # Inbound: WebRTC Media Relay UDP Port Range (49152 - 65535)
  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"
    udp_options {
      min = 49152
      max = 65535
    }
  }
}

# 5. Public Subnet
resource "oci_core_subnet" "public_subnet" {
  cidr_block        = "10.0.1.0/24"
  display_name      = "baby-monitor-public-subnet"
  dns_label         = "public"
  security_list_ids = [oci_core_security_list.baby_monitor_sl.id]
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.baby_monitor_vcn.id
  route_table_id    = oci_core_route_table.rt.id
  dhcp_options_id   = oci_core_vcn.baby_monitor_vcn.default_dhcp_options_id
}

# 6. Oracle Cloud Always Free Ampere A1 Compute Instance (ARM64)
# 4 OCPUs, 24 GB RAM (Always Free!)
resource "oci_core_instance" "monitor_server" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "baby-monitor-relay-server"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    display_name     = "primary-vnic"
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    # Cloud-Init to automatically install Docker and Git on first boot
    user_data = base64encode(<<-EOF
      #!/bin/bash
      dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
      dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin git
      systemctl enable --now docker
      usermod -aG docker opc
    EOF
    )
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

output "instance_public_ip" {
  value       = oci_core_instance.monitor_server.public_ip
  description = "Public IP address of the Baby Monitor relay instance"
}
