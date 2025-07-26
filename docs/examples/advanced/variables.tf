# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "vor-advanced-cluster"
}

variable "location" {
  description = "GCP zone where the cluster will be created"
  type        = string
}

variable "region" {
  description = "GCP region for regional resources"
  type        = string
}

variable "project_id" {
  description = "GCP project ID where resources will be created"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster"
  type        = string
  default     = "1.28"
}

variable "network_self_link" {
  description = "VPC network self-link"
  type        = string
}

variable "subnetwork_self_link" {
  description = "VPC subnetwork self-link"
  type        = string
}

variable "availability_zones" {
  description = "List of zones where nodes can be created"
  type        = list(string)
  default     = []
}
