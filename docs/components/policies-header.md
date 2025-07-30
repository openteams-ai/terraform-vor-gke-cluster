## Access Control and Encryption Policies for GKE

This security configuration enforces **least privilege access**, **API scope restrictions**, and **strong data protection policies**. It supports both baseline and hardened security postures for regulated or critical workloads.


### 1. IAM Roles: Least-Privilege Service Accounts

Each node pool is assigned a **dedicated service account** with the minimal roles required to function. These roles are explicitly chosen to support telemetry and basic GKE operations without overprovisioning.

```hcl
node_group_service_account_roles = [
  "roles/logging.logWriter",
  "roles/monitoring.metricWriter",
  "roles/monitoring.viewer",
  "roles/stackdriver.resourceMetadata.writer",
  "roles/container.nodeServiceAccount"
]
```

This eliminates the risk of running nodes with default, overly broad service accounts, which can lead to unintended access across projects or services.


### 2. OAuth Scopes: Defense-in-Depth API Boundaries

In addition to IAM roles, **OAuth scopes** act as a secondary security boundary, restricting which APIs the node's service account can interact with.

```hcl
node_group_oauth_scopes = [
  "https://www.googleapis.com/auth/logging.write",
  "https://www.googleapis.com/auth/monitoring",
  "https://www.googleapis.com/auth/devstorage.read_only",
  "https://www.googleapis.com/auth/servicecontrol",
  "https://www.googleapis.com/auth/service.management.readonly",
  "https://www.googleapis.com/auth/trace.append"
]
```

For example, granting only **read-only access to storage**:

* Ensures container image pulls from trusted registries
* Prevents upload or modification of containers by compromised nodes
* Adds a critical layer of protection against malicious injection


### 3. Binary Authorization: Image Integrity Enforcement

For environments requiring high assurance, **Binary Authorization** can be enabled to enforce that only **signed and vetted container images** are allowed in the cluster.

```hcl
enable_binary_authorization = var.enable_binary_authorization
```

This ensures every deployed container has passed predefined policies and cryptographic checks—ideal for regulated or security-sensitive applications.


### 4. CMEK: Customer-Managed Encryption Keys

To gain full control over data-at-rest encryption, you can supply a **customer-managed key** for encrypting Kubernetes secrets and etcd storage:

```hcl
dynamic "database_encryption" {
  for_each = var.database_encryption_key_name != "" ? [1] : []
  content {
    state    = "ENCRYPTED"
    key_name = var.database_encryption_key_name
  }
}
```

This setup goes beyond Google’s default encryption by enabling **key rotation**, **revocation**, and **audit logging** under your control—an essential requirement for compliance frameworks such as HIPAA, PCI-DSS, or FedRAMP.
