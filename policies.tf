# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

# Create a dedicated service account for GKE nodes with minimal permissions
resource "google_service_account" "main" {
  account_id   = "${var.name}-gke-nodes"
  display_name = "${var.name} GKE Node Pool Service Account"
  description  = "Service account for GKE node pools with minimal required permissions"
}

# Bind minimal required roles to the service account
resource "google_project_iam_member" "main" {
  for_each = toset(local.node_group_service_account_roles)

  role    = each.value
  member  = "serviceAccount:${google_service_account.main.email}"
  project = var.project_id
}
