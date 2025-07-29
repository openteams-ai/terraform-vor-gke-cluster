# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

module "vor_gke" {
  source = "../../"

  name               = var.cluster_name
  location           = var.location
  region             = var.region
  project_id         = var.project_id
  kubernetes_version = var.kubernetes_version

  # Use existing VPC for advanced configuration
  create_vpc                    = false
  network_self_link             = var.network_self_link
  subnetwork_self_link          = var.subnetwork_self_link
  pods_secondary_range_name     = "pods"
  services_secondary_range_name = "services"

  # Multi-zone configuration
  availability_zones = var.availability_zones

  # Authorized networks for enhanced security
  authorized_networks = [
    {
      cidr_block   = "203.0.113.0/24"
      display_name = "Office Network"
    }
  ]

  # Node pool defaults
  node_group_defaults = {
    min_size      = 1
    max_size      = 10
    instance_type = "e2-standard-2"
    preemptible   = false
  }

  # Multiple node pools
  node_groups = [
    {
      name          = "general"
      min_size      = 2
      max_size      = 10
      instance_type = "e2-standard-2"
      labels = {
        workload = "general"
      }
    },
    {
      name          = "compute-optimized"
      min_size      = 0
      max_size      = 20
      instance_type = "c2-standard-8"
      preemptible   = true
      node_taints = [
        {
          key    = "compute-optimized"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
      labels = {
        workload = "compute"
      }
    },
    {
      name          = "gpu-nodes"
      min_size      = 0
      max_size      = 5
      instance_type = "n1-standard-4"
      guest_accelerators = [
        {
          name  = "nvidia-tesla-t4"
          count = 1
        }
      ]
      node_taints = [
        {
          key    = "nvidia.com/gpu"
          value  = "present"
          effect = "NO_SCHEDULE"
        }
      ]
      labels = {
        workload = "gpu"
      }
    }
  ]

  # Additional IAM roles and OAuth scopes for advanced use cases
  additional_node_group_roles = [
    "roles/storage.objectViewer"
  ]

  additional_node_group_oauth_scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  # Optional: Enable binary authorization for production
  enable_binary_authorization = true

  # Labels and tags
  labels = {
    environment = "production"
    team        = "vor"
    example     = "advanced"
  }

  tags = ["vor-cluster", "production", "advanced-example"]
}
