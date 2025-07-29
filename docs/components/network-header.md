# GKE Network Security Configuration Guide

## Overview

This guide explains the network security architecture and design decisions in our GKE Terraform setup. Understanding these configurations is crucial for maintaining security posture and troubleshooting network connectivity issues.

## VPC Creation Strategy

### Custom VPC vs Existing VPC

```hcl
# Create dedicated VPC (recommended for security isolation)
create_vpc = true

# Or use existing VPC (for shared infrastructure)
create_vpc = false
network_self_link = "projects/my-project/global/networks/existing-vpc"
```

**Why create a custom VPC**:
- **Network isolation**: Separate network boundary for GKE workloads
- **Custom CIDR planning**: Control IP address allocation for better organization
- **Firewall rule isolation**: Dedicated firewall rules that don't conflict with other services
- **Compliance requirements**: Many security frameworks require network segmentation

**When to use existing VPC**:
- **Hybrid connectivity**: Need to integrate with on-premises networks via VPN/Interconnect
- **Shared services**: Resources that need to communicate with existing infrastructure
- **Cost optimization**: Reduce the number of VPCs in large organizations

## IP Address Planning and Secondary Ranges

```hcl
# Primary subnet for node instances
primary_subnet_cidr = "10.0.0.0/24"    # 256 IPs for nodes

# Secondary ranges for Kubernetes networking
pods_subnet_cidr = "10.1.0.0/16"       # 65k IPs for pods
services_subnet_cidr = "10.2.0.0/16"   # 65k IPs for services
```

**CIDR sizing rationale**:

1. **Node subnet (/24)**:
   - Typically only need 10-100 nodes per cluster
   - /24 provides 256 IPs with room for growth
   - Allows for multiple clusters in different /24 blocks

2. **Pod subnet (/16)**:
   - Each node can run 100+ pods
   - Large range prevents IP exhaustion during scaling
   - Kubernetes allocates pod CIDRs to nodes dynamically

3. **Service subnet (/16)**:
   - Services get stable IP addresses
   - Load balancers and ingresses consume IPs
   - Future-proofs for service mesh deployments

## Private Cluster Networking

### NAT Gateway Configuration

```hcl
# Automatic NAT gateway creation for private nodes
resource "google_compute_router_nat" "gke_nat" {
  count  = var.create_vpc ? 1 : 0
  name   = "${var.vpc_name}-nat"
  router = google_compute_router.gke_router[0].name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
```

**Why NAT is essential for private clusters**:
- **Container image pulls**: Nodes need internet access to pull images from registries
- **Package updates**: OS and security updates require outbound connectivity
- **External API calls**: Workloads may need to access external services
- **Security boundary**: NAT provides controlled outbound access without exposing nodes

### VPC Flow Logs for Security Monitoring

```hcl
log_config {
  aggregation_interval = "INTERVAL_5_SEC"
  flow_sampling        = 0.5
  metadata            = "INCLUDE_ALL_METADATA"
}
```

**Security benefits of VPC Flow Logs**:
- **Network monitoring**: Track all traffic between pods and external services
- **Anomaly detection**: Identify unusual traffic patterns that may indicate compromise
- **Compliance auditing**: Meet requirements for network traffic logging
- **Troubleshooting**: Debug connectivity issues and performance problems

**Flow log configuration rationale**:
- **5-second intervals**: Balance between granularity and log volume
- **50% sampling**: Reduces costs while maintaining visibility
- **Full metadata**: Includes source/destination details for security analysis

## Firewall Security Architecture

### Default-Deny Approach

```hcl
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${var.vpc_name}-deny-all-ingress"
  network = google_compute_network.gke_vpc[0].name

  deny {
    protocol = "all"
  }

  direction = "INGRESS"
  priority  = 65534  # Lower priority than allow rules
}
```

**Why default-deny is critical**:
- **Zero-trust principle**: Nothing is allowed unless explicitly permitted
- **Reduced attack surface**: Prevents accidental exposure of services
- **Compliance requirement**: Many security frameworks mandate default-deny policies

### Required GKE Firewall Rules

```hcl
# Master to nodes communication
resource "google_compute_firewall" "gke_master_to_nodes" {
  name    = "${var.vpc_name}-gke-master-to-nodes"
  network = google_compute_network.gke_vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["10250", "443"]  # Kubelet and HTTPS
  }

  source_ranges = [var.master_ipv4_cidr_block]
  target_tags   = ["gke-node"]
}
```

**Critical GKE communication paths**:
1. **Master to kubelet (10250)**: Required for pod management and health checks
2. **Master to nodes (443)**: Webhook admission controllers and API proxy
3. **Node to node**: Inter-pod communication for services
4. **Health check ingress**: GCP load balancer health checks

## Network Policies with Calico

### Why Calico Over Default

```hcl
network_policy {
  enabled  = true
  provider = "CALICO"
}
```

**Calico advantages over basic Kubernetes NetworkPolicy**:
- **Advanced selectors**: More flexible pod and namespace matching
- **Global policies**: Cluster-wide policies that apply to all namespaces
- **Host endpoint policies**: Control traffic to/from nodes themselves
- **Integration capabilities**: Better integration with service mesh and monitoring

### Network Policy Strategy

**Recommended policy patterns**:

1. **Default namespace isolation**:
   ```yaml
   # Deny all traffic between namespaces by default
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: default-deny-all
   spec:
     podSelector: {}
     policyTypes: ["Ingress", "Egress"]
   ```

2. **Explicit service communication**:
   ```yaml
   # Allow specific service-to-service communication
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: allow-frontend-to-backend
   spec:
     podSelector:
       matchLabels:
         app: backend
     ingress:
     - from:
       - podSelector:
           matchLabels:
             app: frontend
   ```

## Master Network Isolation

### Private Master Configuration

```hcl
private_cluster_config {
  master_ipv4_cidr_block = var.master_ipv4_cidr_block  # e.g., "172.16.0.0/28"
}
```

**Master CIDR considerations**:
- **Size**: /28 provides 16 IPs, sufficient for HA master nodes
- **Range selection**: Use RFC 1918 private ranges that don't conflict with node/pod CIDRs
- **Regional scope**: Master IPs are regional, not zonal

### Authorized Networks for API Access

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

**Authorized networks strategy**:
- **Office networks**: Include your organization's public IP ranges
- **VPN endpoints**: Allow access from VPN exit points
- **CI/CD systems**: Include build system IP ranges for deployments
- **Monitoring systems**: External monitoring that needs API access

**Security considerations**:
- **Regular audits**: Review and update authorized networks quarterly
- **Principle of least privilege**: Only include necessary IP ranges
- **Documentation**: Maintain clear descriptions for each CIDR block

## Network Performance Optimizations

### VPC-Native Benefits

Our configuration uses VPC-native networking, which provides:

1. **Direct routing**: Pod traffic routes directly through VPC without overlay networks
2. **Better performance**: Eliminates encapsulation overhead
3. **Native load balancing**: GCP load balancers can directly target pods
4. **Simplified troubleshooting**: Standard VPC tools work with pod traffic

### Regional Persistent Disks

```hcl
location_policy {
  locations = var.availability_zones
}
```

**Network implications**:
- **Cross-zone replication**: Disk replication traffic stays within the region
- **Reduced latency**: Pods can access disks from any zone
- **Network bandwidth**: Higher throughput compared to zonal disks

## Key Network Security Takeaways

1. **Defense in Depth**: Multiple network security layers (VPC isolation, private clusters, network policies, firewall rules)

2. **Zero Trust Networking**: Default-deny policies with explicit allow rules

3. **Observability**: VPC Flow Logs provide visibility into all network traffic

4. **Scalable IP Planning**: Proper CIDR allocation prevents future network conflicts

5. **Performance and Security**: VPC-native networking provides both better performance and security

6. **Operational Excellence**: Clear network boundaries and documentation for troubleshooting

This network configuration establishes a secure foundation that scales with your organization while maintaining strong security boundaries.

---

## Technical Reference

For detailed technical specifications, variables, and outputs, see the [auto-generated documentation](network.md).
