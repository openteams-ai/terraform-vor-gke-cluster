# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

# Enable required APIs
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service#disable_dependent_services-1
resource "google_project_service" "compute" {
  service                    = "compute.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "container" {
  service                    = "container.googleapis.com"
  disable_dependent_services = true
}

# Custom VPC for enhanced security isolation
resource "google_compute_network" "main" {
  #checkov:skip=CKV2_GCP_18:Firewall rules already configured
  count                   = var.create_vpc ? 1 : 0
  name                    = "${var.name}-vpc"
  description             = "Custom VPC for ${var.name} GKE cluster, managed by Terraform"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  depends_on              = [google_project_service.compute]
}

# Primary subnet for GKE nodes
resource "google_compute_subnetwork" "main" {
  count         = var.create_vpc ? 1 : 0
  name          = "${var.name}-subnet"
  ip_cidr_range = var.primary_subnet_cidr
  region        = var.region
  network       = google_compute_network.main[0].id

  # Secondary ranges for pods and services
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_subnet_cidr
  }

  # https://cloud.google.com/vpc/docs/flow-logs
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_subnet_cidr
  }

  # VPC Flow Logs
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  # Enable private Google Access
  private_ip_google_access = true
}

# Router for NAT Gateway (always created when using custom VPC)
resource "google_compute_router" "main" {
  count       = var.create_vpc ? 1 : 0
  name        = "${var.name}-router"
  region      = var.region
  network     = google_compute_network.main[0].id
  description = "Router for ${var.name} GKE cluster NAT Gateway, managed by Terraform"
}

# NAT Gateway for outbound internet access from private nodes
resource "google_compute_router_nat" "main" {
  count  = var.create_vpc ? 1 : 0
  name   = "${var.name}-nat"
  router = google_compute_router.main[0].name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

################################
# Firewall rules for security
################################

# Security firewall rules (only when creating VPC)
resource "google_compute_firewall" "deny_all_ingress" {
  count       = var.create_vpc ? 1 : 0
  name        = "${var.name}-deny-all-ingress"
  network     = google_compute_network.main[0].name
  description = "[${var.name}] Default deny all ingress traffic for GKE cluster security, managed by Terraform"
  direction   = "INGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# Allow internal communication within VPC
resource "google_compute_firewall" "allow_internal" {
  count       = var.create_vpc ? 1 : 0
  name        = "${var.name}-allow-internal"
  network     = google_compute_network.main[0].name
  description = "[${var.name}] Allow internal GKE cluster communication within VPC subnets, managed by Terraform"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.primary_subnet_cidr,
    var.pods_subnet_cidr,
    var.services_subnet_cidr
  ]
}

# Allow GKE health checks
resource "google_compute_firewall" "allow_health_checks" {
  count       = var.create_vpc ? 1 : 0
  name        = "${var.name}-allow-health-checks"
  network     = google_compute_network.main[0].name
  description = "[${var.name}] Allow Google Cloud health checks for GKE load balancers"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
    "209.85.152.0/22",
    "209.85.204.0/22"
  ]

  target_tags = ["gke-node"]
}
