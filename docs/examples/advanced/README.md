# Advanced GKE Cluster Example

This example creates a production-ready GKE cluster using an **existing VPC** with multiple node pools, GPU support, and advanced security configuration.

## Features

- **Existing VPC integration** - Uses your existing network infrastructure
- **Multiple node pools** with different purposes:
  - General purpose nodes (e2-standard-2)
  - Compute-optimized nodes (c2-standard-8, preemptible)
  - GPU nodes (n1-standard-4 with Tesla T4 GPUs)
- **Security-hardened** - All security features enabled by default
- **Production-ready** - Binary authorization, network policies, private nodes
- **Node taints and labels** for workload isolation
- **Custom IAM roles** and OAuth scopes

## Prerequisites

- Existing VPC network with appropriate subnets
- GCP quotas for GPU instances (if using GPU node pool)
- Secondary IP ranges configured for pods and services

## Usage

1. **Update the variables** in `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Ensure you have the necessary GCP quotas** for GPU instances

3. **Deploy the cluster**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Files

- `main.tf` - Main configuration using existing VPC
- `variables.tf` - Variable definitions
- `terraform.tfvars.example` - Example variables file
- `outputs.tf` - Output definitions

## Important Notes

- **Existing VPC Required**: This example assumes you have an existing VPC with:
  - Configured secondary IP ranges for pods and services
  - Appropriate firewall rules for GKE
  - NAT gateway for private node internet access (if needed)

- **GPU Quotas**: Request GPU quotas in your GCP project before applying
- **Security**: All security features (private nodes, network policies, etc.) are enabled automatically
- **Cost Optimization**: Uses preemptible instances for compute-optimized workloads
