# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "name" {
  description = "Name of the GKE cluster and associated resources"
  type        = string
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
}

# ==============================================================================
# NETWORK CONFIGURATION
# ==============================================================================

variable "create_vpc" {
  description = "Whether to create a new VPC or use existing network resources"
  type        = bool
  default     = true
}

# Variables for existing VPC (when create_vpc = false)
variable "network_self_link" {
  description = "Self link of existing VPC network (when create_vpc is false)"
  type        = string
  default     = ""
}

variable "subnetwork_self_link" {
  description = "Self link of existing subnetwork (when create_vpc is false)"
  type        = string
  default     = ""
}

variable "pods_secondary_range_name" {
  description = "Name of secondary range for pods (when using existing VPC)"
  type        = string
  default     = ""
}

variable "services_secondary_range_name" {
  description = "Name of secondary range for services (when using existing VPC)"
  type        = string
  default     = ""
}

# Variables for new VPC (when create_vpc = true)
variable "primary_subnet_cidr" {
  description = "CIDR range for the primary subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "pods_subnet_cidr" {
  description = "CIDR range for pods secondary subnet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_subnet_cidr" {
  description = "CIDR range for services secondary subnet"
  type        = string
  default     = "10.2.0.0/16"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the master network"
  type        = string
  default     = "172.16.0.0/28"
}

variable "authorized_networks" {
  description = "List of authorized networks that can access the cluster master"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

# ==============================================================================
# NODE POOL CONFIGURATION
# ==============================================================================

variable "node_groups" {
  description = "List of node pool configurations"
  type = list(object({
    name          = string
    min_size      = number
    max_size      = number
    instance_type = string
    preemptible   = optional(bool, false)
    node_taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    guest_accelerators = optional(list(object({
      name               = string
      count              = number
      gpu_partition_size = optional(string, "")
      gpu_driver_version = optional(string, "")
    })), [])
    labels = optional(map(string), {})
  }))
  default = [
    {
      name               = "default"
      min_size           = 1
      max_size           = 3
      instance_type      = "e2-standard-2"
      preemptible        = false
      node_taints        = []
      guest_accelerators = []
      labels             = {}
    }
  ]
}

variable "node_group_defaults" {
  description = "Default values for node groups"
  type = object({
    min_size      = number
    max_size      = number
    instance_type = string
    preemptible   = optional(bool, false)
    node_taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    guest_accelerators = optional(list(object({
      name               = string
      count              = number
      gpu_partition_size = optional(string, "")
    })), [])
    labels = optional(map(string), {})
  })
  default = {
    min_size           = 1
    max_size           = 3
    instance_type      = "e2-standard-2"
    preemptible        = false
    node_taints        = []
    guest_accelerators = []
    labels             = {}
  }
}

# ==============================================================================
# SECURITY CONFIGURATION
# ==============================================================================

variable "enable_private_endpoint" {
  description = "Enable private endpoint for the cluster master (nodes are always private)"
  type        = bool
  default     = false
}

variable "enable_binary_authorization" {
  description = "Enable binary authorization for container image security"
  type        = bool
  default     = false
}

variable "database_encryption_key_name" {
  description = "KMS key name for database encryption at rest"
  type        = string
  default     = ""
}

# ==============================================================================
# CLUSTER CONFIGURATION
# ==============================================================================

variable "availability_zones" {
  description = "List of zones where nodes can be created"
  type        = list(string)
  default     = []
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "STABLE"
}

variable "maintenance_start_time" {
  description = "Start time for daily maintenance window (HH:MM format)"
  type        = string
  default     = "02:00"
}

variable "rbac_security_group" {
  description = "Security group for RBAC authenticator"
  type        = string
  default     = ""
}

# ==============================================================================
# NODE CONFIGURATION
# ==============================================================================

variable "node_disk_type" {
  description = "Disk type for node pools"
  type        = string
  default     = "pd-balanced"
}

variable "node_disk_size_gb" {
  description = "Disk size for node pools in GB"
  type        = number
  default     = 100
}

# ==============================================================================
# IAM CONFIGURATION
# ==============================================================================

variable "additional_node_group_roles" {
  description = "Additional IAM roles for node service account"
  type        = list(string)
  default     = []
}

variable "additional_node_group_oauth_scopes" {
  description = "Additional OAuth scopes for nodes"
  type        = list(string)
  default     = []
}

# ==============================================================================
# OPTIONAL LABELS AND TAGS
# ==============================================================================

variable "labels" {
  description = "Labels to apply to all node pools"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags for node pools"
  type        = list(string)
  default     = []
}
