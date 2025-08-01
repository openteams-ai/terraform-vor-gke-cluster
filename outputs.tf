# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

output "kubeconfig" {
  description = "Kubeconfig for connecting to kubernetes cluster"
  sensitive   = true
  value = templatefile("${path.module}/templates/kubeconfig.yaml.tpl", {
    context                = google_container_cluster.main.name
    cluster_ca_certificate = google_container_cluster.main.master_auth[0].cluster_ca_certificate
    endpoint               = google_container_cluster.main.endpoint
    token                  = data.google_client_config.main.access_token
  })
}

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for the GKE cluster"
  value       = google_container_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded cluster CA certificate"
  sensitive   = true
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
}

output "service_account_email" {
  description = "Email of the service account used by node pools"
  value       = google_service_account.main.email
}

output "node_pools" {
  description = "List of node pool names"
  value       = [for pool in google_container_node_pool.main : pool.name]
}

output "vpc_id" {
  description = "ID of the VPC network"
  value       = var.create_vpc ? google_compute_network.main[0].id : null
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = var.create_vpc ? google_compute_subnetwork.main[0].id : null
}

output "cluster_access_token" {
  description = "Access token for the GKE cluster"
  sensitive   = true
  value       = data.google_client_config.main.access_token
}

output "cluster_security_features" {
  description = "Security features enabled on the cluster"
  value = {
    private_nodes        = true
    private_endpoint     = var.enable_private_endpoint
    network_policy       = true
    binary_authorization = var.enable_binary_authorization
    workload_identity    = true
    shielded_nodes       = true
    database_encryption  = var.database_encryption_key_name != ""
    vpc_native           = true
  }
}