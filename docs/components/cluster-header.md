# GKE Cluster Security Configuration Guide

## Overview

This guide explains the security-focused and non-default configurations in our GKE cluster Terraform setup. It's designed for maintainers and newcomers who want to understand how security hardening and cluster isolation work in production GKE environments.

## Authentication Security

### Client Certificate Disabled

```hcl
master_auth {
  client_certificate_config {
    issue_client_certificate = false
  }
}
```

**Why disable this**: Client certificates are considered a legacy authentication method. Modern GKE uses:
- Service account tokens
- OIDC/OAuth2 integration
- Workload Identity (configured in our setup)

**Security improvement**: Eliminates a potential credential that could be compromised and reduces authentication complexity.

## Private Cluster Architecture

This is one of the most important security features in our configuration:

```hcl
private_cluster_config {
  enable_private_nodes    = true                    # Nodes have no public IPs
  enable_private_endpoint = var.enable_private_endpoint  # API server access control
  master_ipv4_cidr_block  = var.master_ipv4_cidr_block   # Dedicated subnet for masters

  master_global_access_config {
    enabled = false  # Disable global access to API server
  }
}
```

**Security layers explained**:

1. **Private Nodes (`enable_private_nodes = true`)**:
   - Worker nodes get only internal IP addresses
   - No direct internet access to nodes
   - Reduces attack surface significantly
   - Nodes access internet through Cloud NAT if needed

2. **Private Endpoint (optional)**:
   - When enabled, the Kubernetes API server is only accessible from within the VPC
   - Prevents external API access attempts
   - Requires VPN or bastion hosts for kubectl access

3. **Master CIDR Block**:
   - Kubernetes control plane runs in an isolated subnet
   - You define the IP range (typically /28 subnet)
   - Provides network segmentation between control plane and data plane

4. **Master Global Access Disabled**:
   - Prevents access to the API server from outside the region
   - Adds another layer of geographic access control

## Workload Identity Configuration

```hcl
workload_identity_config {
  workload_pool = "${var.project_id}.svc.id.goog"
}
```

**What Workload Identity solves**:
- **Problem**: Traditional setup requires downloading service account keys to pods
- **Solution**: Pods can assume Google Cloud service accounts without storing credentials
- **Security improvement**: No long-lived credentials in containers, automatic key rotation

**How it works**:
1. Kubernetes service account maps to Google service account
2. Pod gets temporary tokens from metadata server
3. Tokens are automatically rotated

## VPC-Native Networking

```hcl
ip_allocation_policy {
  cluster_secondary_range_name  = var.create_vpc ? "pods" : var.pods_secondary_range_name
  services_secondary_range_name = var.create_vpc ? "services" : var.services_secondary_range_name
}
```

**What this enables**:
- **Pod IPs are routable within the VPC**: Pods get real VPC IP addresses instead of overlay network IPs
- **Better network performance**: No NAT/tunneling overhead for pod-to-pod communication
- **Improved security controls**: VPC firewall rules can directly control pod traffic
- **Service mesh compatibility**: Essential for advanced networking features

## Network Policy Enforcement

```hcl
network_policy {
  enabled  = true
  provider = "CALICO"
}

addons_config {
  network_policy_config {
    disabled = false  # Always enabled for security
  }
}
```

**What this enables**:
- **Microsegmentation**: Control pod-to-pod communication with Kubernetes NetworkPolicy objects
- **Default deny**: Can implement "deny all, allow specific" traffic patterns
- **Compliance**: Meet requirements for network isolation between services

**Calico benefits**:
- More advanced policy features than basic Kubernetes NetworkPolicy
- Better performance than alternatives
- Integration with service mesh policies

## Authorized Networks Security

```hcl
dynamic "master_authorized_networks_config" {
  for_each = length(var.authorized_networks) > 0 ? [1] : []
  content {
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }
}
```

**Purpose**: Creates an IP whitelist for Kubernetes API server access
**Security benefit**: Even if someone obtains valid credentials, they can only access the API from approved IP ranges (office networks, VPNs, etc.)

## Release Channel Strategy

```hcl
release_channel {
  channel = var.release_channel  # Default: "STABLE"
}
```

**Channel options and security implications**:
- **RAPID**: Latest features, faster security patches, higher change risk
- **REGULAR**: Balanced updates, moderate security patch timing
- **STABLE**: Well-tested releases, slower but stable security updates

**Why we default to STABLE**: Production environments prioritize stability while still receiving security patches in a controlled manner.

## Optional Security Enhancements

### Binary Authorization

```hcl
enable_binary_authorization = var.enable_binary_authorization
```

**When to use**: High-security environments, compliance requirements
**What it does**:
- Only allows deployment of container images that pass security attestation
- Integrates with vulnerability scanning
- Prevents deployment of unsigned or untrusted images

### Database Encryption at Rest

```hcl
dynamic "database_encryption" {
  for_each = var.database_encryption_key_name != "" ? [1] : []
  content {
    state    = "ENCRYPTED"
    key_name = var.database_encryption_key_name
  }
}
```

**What's encrypted**:
- Kubernetes secrets
- ConfigMaps
- Other etcd data

**Key management**: Uses Google Cloud KMS keys that you control, adding an extra layer beyond Google's default encryption

## Operational Security

### Resource Labeling Strategy

```hcl
resource_labels = merge(var.labels, {
  cluster_name = var.name
  managed_by   = "terraform"
  component    = "gke_cluster"
  environment  = "gke"
})
```

**Security benefits**:
- **Audit trails**: Easier to track resource creation and changes
- **Cost allocation**: Identify security-related expenses
- **Compliance**: Meet tagging requirements for governance

### Maintenance Windows

```hcl
dynamic "maintenance_policy" {
  for_each = var.maintenance_start_time != "" ? [1] : []
  content {
    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }
}
```

**Why control this**: Prevents unexpected downtime during business hours and allows for security patch planning

## Key Security Takeaways

1. **Defense in Depth**: Multiple security layers (network isolation, authentication, authorization, encryption)

2. **Private by Default**: All nodes are private, with controlled access to the API server

3. **Modern Authentication**: Workload Identity instead of static credentials

4. **Network Segmentation**: VPC-native networking with Calico policies

5. **Compliance Ready**: Features like Binary Authorization and database encryption for regulated environments

6. **Operational Security**: Proper labeling and maintenance windows for security operations

This configuration represents a production-ready, security-hardened GKE setup that goes well beyond default settings to provide enterprise-grade protection.

---

## Technical Reference

For detailed technical specifications, variables, and outputs, see the [auto-generated documentation](cluster.md).
