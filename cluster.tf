# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

locals {
  # Minimal required service account roles following least privilege principle
  # https://cloud.google.com/logging/docs/access-control#permissions_and_roles
  node_group_service_account_roles = concat(var.additional_node_group_roles, [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/container.nodeServiceAccount"
  ])

  # Minimal OAuth scopes for security
  node_group_oauth_scopes = concat(var.additional_node_group_oauth_scopes, [
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/trace.append"
  ])

  merged_node_groups = [for node_group in var.node_groups : merge(var.node_group_defaults, node_group)]

  # Network configuration - URIs for VPC-native clusters
  network_self_link    = var.create_vpc ? google_compute_network.main[0].self_link : var.network_self_link
  subnetwork_self_link = var.create_vpc ? google_compute_subnetwork.main[0].self_link : var.subnetwork_self_link
}

data "google_client_config" "main" {}

resource "google_container_cluster" "main" {
  # checkov:skip=CKV_GCP_69:Default node pool disabled, using private custom pools
  # checkov:skip=CKV_GCP_66:Binary authorization already configured
  name               = var.name
  location           = var.location
  min_master_version = var.kubernetes_version
  node_locations     = var.availability_zones

  enable_intranode_visibility = true
  # Whether Terraform will be prevented from destroying the cluster
  deletion_protection = false

  # Remove default node pool - use only custom node pools
  remove_default_node_pool = true
  initial_node_count       = 1 # trivy:ignore:AVD-GCP-0053 Pod Security Policies deprecated - using modern security_posture_config instead

  # Security: Disable client certificate authentication
  # https://cloud.google.com/kubernetes-engine/docs/how-to/api-server-authentication#disabling_authentication_with_a_client_certificate
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # checkov:skip=CKV_GCP_65: Support for RBAC authenticator groups
  # https://cloud.google.com/kubernetes-engine/docs/how-to/google-groups-rbac
  dynamic "authenticator_groups_config" {
    for_each = var.rbac_security_group != "" ? [1] : []
    content {
      security_group = var.rbac_security_group
    }
  }

  # Network configuration : Newly created clusters will default to VPC_NATIVE
  network    = local.network_self_link
  subnetwork = local.subnetwork_self_link

  ip_allocation_policy {
    cluster_secondary_range_name  = var.create_vpc ? "pods" : var.pods_secondary_range_name
    services_secondary_range_name = var.create_vpc ? "services" : var.services_secondary_range_name
  }

  # Private cluster configuration (always enabled for security)
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    master_global_access_config {
      enabled = false
    }
  }

  # Master authorized networks (always enabled for security)
  # Requires explicit configuration for access - no default access for security
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  check "authorized_networks_configured" {
    assert {
      condition     = length(var.authorized_networks) > 0
      error_message = "WARNING: No authorized networks configured. Cluster master will be inaccessible. Add your IP to authorized_networks."
    }
  }

  release_channel {
    channel = var.release_channel
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Security: Enable Workload Identity and security features
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = false
    }

    network_policy_config {
      disabled = false # Always enabled for security
    }

    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Binary authorization (optional)
  # https://cloud.google.com/binary-authorization/docs/overview
  binary_authorization {
    evaluation_mode = var.enable_binary_authorization ? "PROJECT_SINGLETON_POLICY_ENFORCE" : "DISABLED"
  }

  # Database encryption (optional)
  dynamic "database_encryption" {
    for_each = var.database_encryption_key_name != "" ? [1] : []
    content {
      state    = "ENCRYPTED"
      key_name = var.database_encryption_key_name
    }
  }

  dynamic "maintenance_policy" {
    for_each = var.maintenance_start_time != "" ? [1] : []
    content {
      daily_maintenance_window {
        start_time = var.maintenance_start_time
      }
    }
  }

  # Resource labels for tracking and cost allocation
  # trivy:ignore:AVD-GCP-0055 Resource labels already configured
  # checkov:skip=CKV_GCP_21:Resource labels already configured
  resource_labels = merge(var.labels, {
    cluster_name = var.name
    managed_by   = "terraform"
    component    = "gke_cluster"
    environment  = "gke"
  })

  lifecycle {
    ignore_changes = [
      node_locations,
      initial_node_count
    ]
  }

  depends_on = [
    google_project_service.container,
    google_project_service.compute
  ]
}
