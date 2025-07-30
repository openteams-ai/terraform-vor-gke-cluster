## Hardened Node Pool Configuration for GKE

This node pool configuration focuses on **OS-level security, IAM-managed access, minimal permissions**, and automated lifecycle management. It forms the backbone of a resilient and secure GKE workload environment.


### 1. Secure Boot with Shielded VMs

Every node runs as a **Shielded VM**, a hardened Google Compute Engine instance with verified boot, rootkit detection, and enforced integrity.

```hcl
shielded_instance_config {
  enable_secure_boot          = true
  enable_integrity_monitoring = true
}
```

This setup ensures the node's boot sequence is cryptographically verified, unlike standard GKE node pools which may default to non-hardened images.


### 2. Metadata Protection and IAM-Based Access

To prevent metadata-based privilege escalation and ensure secure access control, **legacy metadata endpoints are disabled**, and **OS Login is enabled** for SSH access via IAM.

```hcl
metadata = {
  disable-legacy-endpoints = "true"
  enable-oslogin           = "true"
}
```

This not only reduces surface area for attacks but also centralizes user SSH control using IAM policies—avoiding the risks of unmanaged SSH keys.


### 3. Principle of Least Privilege

Instead of relying on the default overly permissive service account, each node pool is bound to a **dedicated service account** with minimal required scopes:

```hcl
service_account = google_service_account.main.email
oauth_scopes    = [
  "https://www.googleapis.com/auth/logging.write",
  "https://www.googleapis.com/auth/monitoring",
  "https://www.googleapis.com/auth/devstorage.read_only"
]
```

This enforces fine-grained access to only the resources needed for telemetry and secure image pulls, aligning with enterprise security standards.


### 4. Lifecycle Automation

**Automatic repair and upgrade** features are enabled to ensure high availability and quick remediation of security vulnerabilities:

```hcl
management {
  auto_repair  = true
  auto_upgrade = true
}
```

This guarantees that critical security patches are applied promptly and that failing nodes are replaced without manual intervention.


### 5. Hardened Container Runtime

All nodes run **Container-Optimized OS (COS)** using the **containerd** runtime, providing a minimal attack surface and enhanced performance compared to legacy Docker-based configurations.
