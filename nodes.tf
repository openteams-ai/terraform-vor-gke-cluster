# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

resource "google_container_node_pool" "main" {
  count = length(local.merged_node_groups)

  name     = local.merged_node_groups[count.index].name
  location = var.location
  cluster  = google_container_cluster.main.name
  version  = var.kubernetes_version

  initial_node_count = local.merged_node_groups[count.index].min_size

  autoscaling {
    min_node_count = local.merged_node_groups[count.index].min_size
    max_node_count = local.merged_node_groups[count.index].max_size
  }

  management {
    auto_repair  = true
    auto_upgrade = true # Enable for security updates
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    preemptible  = local.merged_node_groups[count.index].preemptible
    machine_type = local.merged_node_groups[count.index].instance_type
    image_type   = "COS_CONTAINERD" # Always use secure image
    disk_type    = var.node_disk_type
    disk_size_gb = var.node_disk_size_gb

    service_account = google_service_account.main.email
    oauth_scopes    = local.node_group_oauth_scopes

    # Security: Shielded VMs with secure boot (always enabled)
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Security: Workload metadata security
    workload_metadata_config {
      mode          = "GKE_METADATA"
      node_metadata = "GKE_METADATA_SERVER"
    }

    # Node taints
    dynamic "taint" {
      for_each = local.merged_node_groups[count.index].node_taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    # Security metadata
    metadata = {
      disable-legacy-endpoints         = "true" # trivy:ignore:AVD-GCP-0052 Legacy endpoints already disabled
      google-compute-enable-virtio-rng = "true"
      enable-oslogin                   = "true"
    }

    # Node labels
    labels = merge(
      local.merged_node_groups[count.index].labels,
      var.labels,
      {
        "cluster-name" = var.name
        "node-pool"    = local.merged_node_groups[count.index].name
        "managed-by"   = "terraform"
        "component"    = "gke-node"
        "environment"  = "gke"
      }
    )

    # GPU accelerators
    dynamic "guest_accelerator" {
      for_each = local.merged_node_groups[count.index].guest_accelerators
      content {
        type               = guest_accelerator.value.name
        count              = guest_accelerator.value.count
        gpu_partition_size = guest_accelerator.value.gpu_partition_size != "" ? guest_accelerator.value.gpu_partition_size : null
      }
    }

    # Network tags
    tags = concat(var.tags, ["gke-node", "${var.name}-node"])
  }

  # Network configuration (always private for security)
  network_config {
    create_pod_range     = false
    enable_private_nodes = true
  }

  depends_on = [
    google_service_account.main,
    google_project_iam_member.main
  ]
}
