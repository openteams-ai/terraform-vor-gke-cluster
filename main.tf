# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

# Terraform configuration for Vor GKE Infrastructure Module
# This file contains data sources used across the module

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
