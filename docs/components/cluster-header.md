## Secure GKE Cluster Configuration

This setup defines a production-grade, security-hardened Google Kubernetes Engine (GKE) cluster. It prioritizes **private networking**, **modern authentication**, and **least-privilege identity management**—while maintaining flexibility through optional features like **Binary Authorization** and **CMEK encryption**.

### 1. Networking and Isolation

At the foundation, the cluster is **private by design**: nodes are launched without public IPs and the control plane is placed inside an isolated subnet. Public access is disabled unless explicitly allowed.

```hcl
private_cluster_config {
  enable_private_nodes    = true
  enable_private_endpoint = var.enable_private_endpoint
  master_ipv4_cidr_block  = var.master_ipv4_cidr_block

  master_global_access_config {
    enabled = false
  }
}
```

Networking follows a **VPC-native model**, assigning pods real VPC IPs for better observability and policy enforcement:

```hcl
ip_allocation_policy {
  cluster_secondary_range_name  = var.create_vpc ? "pods" : var.pods_secondary_range_name
  services_secondary_range_name = var.create_vpc ? "services" : var.services_secondary_range_name
}
```

This allows tight **firewall-level control** over pod-to-pod and service traffic, as well as integration with **Calico network policies** for fine-grained segmentation:

```hcl
network_policy {
  enabled  = true
  provider = "CALICO"
}
```

To further reduce exposure, the API server can be locked down to specific **authorized CIDR blocks**:

```hcl
master_authorized_networks_config {
  dynamic "cidr_blocks" {
    for_each = var.authorized_networks
    content {
      cidr_block   = cidr_blocks.value.cidr_block
      display_name = cidr_blocks.value.display_name
    }
  }
}
```

---

### 2. Authentication and Identity

Legacy client certificate authentication is explicitly disabled in favor of more secure alternatives:

```hcl
master_auth {
  client_certificate_config {
    issue_client_certificate = false
  }
}
```

Instead, the cluster leverages **Workload Identity**, binding Kubernetes ServiceAccounts to Google Cloud IAM roles without needing static keys:

```hcl
workload_identity_config {
  workload_pool = "${var.project_id}.svc.id.goog"
}
```

This approach avoids risks associated with embedded service account keys in containers, aligning with least-privilege principles.

---

### 3. Stability and Operational Controls

For stability, the cluster adopts the **STABLE** GKE release channel:

```hcl
release_channel {
  channel = var.release_channel  # Default: "STABLE"
}
```

You can also define **maintenance windows** to control update timing and ensure upgrades happen during safe periods.

---

### 4. Optional Hardening Features

Further layers of security can be optionally enabled:

* **Binary Authorization**: Ensures only signed container images can run.
* **CMEK Support**: Enables encryption of etcd data using customer-managed keys.
* **Maintenance Windows**: Scheduled update slots to minimize surprise rollouts.
