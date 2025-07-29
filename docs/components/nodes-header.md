# GKE Node Pool Security Configuration Guide

## Overview

This guide explains the security configurations and design decisions for GKE node pools in our Terraform setup. Understanding these settings is essential for maintaining a secure and compliant Kubernetes environment.

## Node Security Hardening

### Shielded VMs Configuration

```hcl
shielded_instance_config {
  enable_secure_boot          = true
  enable_integrity_monitoring = true
}
```

**What Shielded VMs provide**:
- **Secure Boot**: Verifies the digital signature of boot components
- **Integrity Monitoring**: Detects unauthorized changes to the VM
- **vTPM**: Virtual Trusted Platform Module for cryptographic operations

**Security benefits**:
- **Rootkit protection**: Prevents malicious code from loading during boot
- **Compliance**: Meets requirements for high-security environments
- **Attestation**: Provides cryptographic proof of system integrity

### Metadata Security Configuration

```hcl
metadata = {
  disable-legacy-endpoints = "true"  # Disable legacy metadata endpoints
  enable-oslogin          = "true"   # Use Google Cloud OS Login for SSH
}
```

**Why disable legacy endpoints**:
- **Attack surface reduction**: Legacy endpoints have fewer security controls
- **Compliance**: Modern security standards require disabling legacy features
- **Access control**: New endpoints provide better audit logging

**OS Login benefits**:
- **Centralized access control**: Manage SSH access through Google Cloud IAM
- **No SSH key management**: Eliminates need to distribute SSH keys
- **Audit logging**: All SSH access is logged and attributed to users

## Service Account Security & Permissions

### Minimal Privilege Service Account Roles

```hcl
node_group_service_account_roles = [
  "roles/logging.logWriter",           # Write logs to Cloud Logging
  "roles/monitoring.metricWriter",     # Send metrics to Cloud Monitoring
  "roles/monitoring.viewer",           # Read monitoring data
  "roles/stackdriver.resourceMetadata.writer", # Write resource metadata
  "roles/container.nodeServiceAccount" # Basic GKE node operations
]
```

**Why this matters**: Default GKE nodes often get overly broad permissions. This configuration restricts access to only what's needed for basic operations, reducing the attack surface if a node is compromised.

### OAuth Scopes Restriction

```hcl
node_group_oauth_scopes = [
  "https://www.googleapis.com/auth/logging.write",
  "https://www.googleapis.com/auth/monitoring",
  "https://www.googleapis.com/auth/devstorage.read_only",  # Read-only storage access
  "https://www.googleapis.com/auth/servicecontrol",
  "https://www.googleapis.com/auth/service.management.readonly",
  "https://www.googleapis.com/auth/trace.append"
]
```

**Security benefit**: Prevents nodes from accessing services they don't need, like write access to Cloud Storage or administrative APIs.

## Disk Security Configuration

### Boot Disk Encryption

```hcl
disk_encryption_key = var.node_disk_encryption_key
disk_type          = "pd-balanced"  # Performance + security balance
disk_size_gb       = 100           # Sufficient for container images and logs
```

**Disk type considerations**:
- **pd-balanced**: Good performance with encryption at rest
- **pd-ssd**: Higher IOPS for I/O intensive workloads
- **pd-standard**: Cost-optimized for basic workloads

**Why 100GB is the minimum**:
- **Container images**: Multiple large images can consume significant space
- **System logs**: Kubernetes and application logs require storage
- **Temporary files**: Container builds and temporary data need space

### Image Type Security

```hcl
image_type = "COS_CONTAINERD"  # Container-Optimized OS with containerd
```

**Why Container-Optimized OS (COS)**:
- **Minimal attack surface**: Stripped-down OS with only essential components
- **Automatic updates**: Google manages security patches
- **Container-focused**: Optimized for running containers securely
- **Read-only root**: Root filesystem is read-only for additional security

**containerd advantages**:
- **Better security isolation**: Improved container runtime security
- **Performance**: Lower overhead than Docker
- **Industry standard**: CNCF graduated project with strong security focus

## Node Pool Scaling and Availability

### Auto-scaling Configuration

```hcl
node_count = null  # Use auto-scaling instead of fixed count

autoscaling {
  min_node_count = var.min_size
  max_node_count = var.max_size
}
```

**Security implications of auto-scaling**:
- **Resource exhaustion protection**: Prevents DoS attacks from consuming all nodes
- **Cost control**: Limits maximum resource usage
- **Availability**: Automatically scales up during high demand

### Node Auto-repair and Auto-upgrade

```hcl
management {
  auto_repair  = true   # Automatically repair unhealthy nodes
  auto_upgrade = false  # Disable automatic upgrades for production control
}
```

**Why auto-repair is enabled**:
- **Security hygiene**: Automatically replaces compromised or failing nodes
- **Reduced operational overhead**: Eliminates manual node replacement
- **Consistency**: Ensures all nodes meet baseline configuration

**Why auto-upgrade is disabled**:
- **Change control**: Production environments need controlled upgrade schedules
- **Testing requirements**: New versions should be tested before deployment
- **Security validation**: Security teams need to validate new node images

## Workload Identity Configuration

### Node Workload Identity Setup

```hcl
workload_metadata_config {
  mode = "GKE_METADATA"  # Enable Workload Identity metadata server
}
```

**How Workload Identity improves security**:
1. **No service account keys**: Eliminates long-lived credentials in containers
2. **Automatic token rotation**: Tokens are automatically refreshed
3. **Fine-grained permissions**: Each workload can have different permissions
4. **Audit trail**: All API calls are attributed to specific Kubernetes service accounts

## Node Pool Specialization Strategies

### General Purpose Pools

```hcl
# Standard workloads
node_groups = [{
  name          = "general"
  min_size      = 2
  max_size      = 10
  instance_type = "e2-standard-4"
}]
```

**e2-standard-4 rationale**:
- **Balanced resources**: 4 vCPUs, 16GB RAM suitable for most workloads
- **Cost-effective**: Good price/performance ratio
- **Security features**: All modern security features supported

### Compute-Optimized Pools

```hcl
{
  name          = "compute-optimized"
  instance_type = "c2-standard-8"
  preemptible   = true
  node_taints = [{
    key    = "compute-optimized"
    value  = "true"
    effect = "NO_SCHEDULE"
  }]
}
```

**Security considerations for preemptible nodes**:
- **Ephemeral nature**: Nodes can be terminated at any time
- **Workload suitability**: Only for stateless, fault-tolerant workloads
- **Cost savings**: Significant cost reduction for appropriate workloads

**Taint strategy**:
- **Workload isolation**: Ensures only designated workloads run on specialized nodes
- **Resource optimization**: Prevents general workloads from consuming specialized resources

### GPU-Enabled Pools

```hcl
{
  name          = "gpu-nodes"
  instance_type = "n1-standard-4"
  guest_accelerators = [{
    name  = "nvidia-tesla-t4"
    count = 1
  }]
  node_taints = [{
    key    = "nvidia.com/gpu"
    value  = "present"
    effect = "NO_SCHEDULE"
  }]
}
```

**GPU security considerations**:
- **Driver isolation**: GPU drivers run in privileged mode
- **Resource sharing**: GPUs cannot be shared securely between untrusted workloads
- **Compliance**: Some compliance frameworks restrict GPU usage

**Standard GPU taint**:
- **nvidia.com/gpu**: Industry standard taint for GPU nodes
- **Workload targeting**: Ensures only GPU workloads run on expensive GPU nodes

## Network Security for Nodes

### Private Node Configuration

```hcl
# All nodes are private by default in our configuration
enable_private_nodes = true
```

**Benefits of private nodes**:
- **No public IP exposure**: Nodes cannot be directly accessed from the internet
- **Reduced attack surface**: External attackers cannot directly target nodes
- **Compliance**: Many security frameworks require private compute resources

### Node Network Tags

```hcl
tags = concat(var.tags, ["gke-node", var.cluster_name])
```

**Why network tags matter**:
- **Firewall targeting**: Firewall rules can target specific node types
- **Security groups**: Group nodes for consistent security policies
- **Monitoring**: Tag-based monitoring and alerting

## Operational Security

### Resource Labeling for Nodes

```hcl
labels = merge(var.labels, {
  cluster_name = var.cluster_name
  managed_by   = "terraform"
  component    = "gke_node_pool"
  environment  = "gke"
  node_pool    = var.name
})
```

**Security and operational benefits**:
- **Cost allocation**: Track compute costs by team or project
- **Compliance auditing**: Identify resources for compliance scans
- **Incident response**: Quickly identify affected resources during incidents

### Node Upgrade Strategy

**Recommended approach**:
1. **Staged rollouts**: Upgrade one node pool at a time
2. **Blue/green deployments**: Create new node pools with new versions
3. **Testing**: Validate new versions in non-production first
4. **Rollback capability**: Maintain ability to quickly rollback changes

## Key Node Security Takeaways

1. **Defense in Depth**: Multiple security layers (Shielded VMs, OS Login, minimal permissions, encryption)

2. **Principle of Least Privilege**: Minimal service account permissions and OAuth scopes

3. **Workload Isolation**: Use taints and specialized node pools to isolate different workload types

4. **Operational Security**: Proper labeling, controlled upgrades, and monitoring

5. **Modern Security Features**: Container-Optimized OS, Workload Identity, and current runtime versions

6. **Cost-Security Balance**: Use preemptible instances appropriately while maintaining security

This node configuration provides a secure foundation for running containerized workloads while maintaining operational flexibility.

---

## Technical Reference

For detailed technical specifications, variables, and outputs, see the [auto-generated documentation](nodes.md).
