# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

output "cluster_name" {
  description = "Name of the created GKE cluster"
  value       = module.vor_gke.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for the GKE cluster"
  value       = module.vor_gke.cluster_endpoint
}

output "service_account_email" {
  description = "Email of the service account used by node pools"
  value       = module.vor_gke.service_account_email
}
