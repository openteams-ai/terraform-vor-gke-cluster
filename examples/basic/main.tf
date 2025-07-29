# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

module "vor_gke" {
  source = "../../"

  name               = var.cluster_name
  location           = var.location
  region             = var.region
  project_id         = var.project_id
  kubernetes_version = var.kubernetes_version

  # Create secure VPC with default settings
  create_vpc = true

  # Basic node pool with secure defaults
  node_groups = [
    {
      name          = "default"
      min_size      = 1
      max_size      = 5
      instance_type = "e2-standard-2"
    }
  ]

  labels = {
    environment = "development"
    example     = "basic"
  }

  tags = ["vor-basic-example"]
}
