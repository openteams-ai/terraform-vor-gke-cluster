## Secure Network Architecture for GKE

This setup provisions a **purpose-built VPC** architecture optimized for a secure, private GKE cluster. It emphasizes **isolation, observability, and intentional IP planning**, avoiding pitfalls of default network configurations.

### 1. VPC Strategy and Isolation

By default, the module provisions a **dedicated Virtual Private Cloud** to isolate the GKE workload from other networks. This ensures tight boundaries and eliminates dependencies on default VPC behavior.

```hcl
create_vpc = true  # Creates custom VPC with dedicated subnets
# OR
create_vpc = false  # Uses existing VPC infrastructure
```

This approach contrasts with default GKE clusters that often use shared or default VPCs, which can lead to cross-project exposure or IP collisions.


### 2. Thoughtful IP Planning

To support scalability and clarity, the module defines **dedicated CIDR blocks** for nodes, pods, and services.

```hcl
primary_subnet_cidr  = "10.0.0.0/24"    # Node IPs
pods_subnet_cidr     = "10.1.0.0/16"    # Pod IPs
services_subnet_cidr = "10.2.0.0/16"    # Service IPs
```

This setup allocates larger blocks to **pods and services** to avoid IP exhaustion during autoscaling, while keeping **node ranges smaller** for manageability. Such planning is rare in default GKE configurations, which often suffer from IP fragmentation.


### 3. Private Cluster Connectivity

To maintain security while allowing necessary egress (e.g., image pulls, updates), **all nodes are private** and use a **Cloud NAT gateway** for outbound traffic:

```hcl
resource "google_compute_router_nat" "main" {
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
```

This ensures **no public IPs** are assigned to nodes—an essential improvement over traditional GKE clusters with public-facing nodes.


### 4. Flow Logging and Observability

**VPC Flow Logs** are enabled to track traffic for security monitoring and compliance, giving operators insight into communication patterns and anomalies.

```hcl
log_config {
  aggregation_interval = "INTERVAL_10_MIN"
  flow_sampling        = 0.5
  metadata             = "INCLUDE_ALL_METADATA"
}
```

Standard GKE clusters typically skip this step, resulting in a lack of visibility into internal traffic.


### 5. Zero-Trust Firewall Rules

The firewall policy enforces a **default-deny stance**, blocking all ingress traffic unless explicitly permitted. This baseline rule is paired with controlled exceptions for internal services and health checks.

```hcl
resource "google_compute_firewall" "deny_all_ingress" {
  deny {
    protocol = "all"
  }
  direction = "INGRESS"
  priority  = 65534
}
```

This **zero-trust model** marks a shift from GKE’s permissive defaults, significantly reducing the attack surface and limiting lateral movement within the cluster.
