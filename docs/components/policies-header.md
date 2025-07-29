# GKE Security Policies Configuration Guide

## Overview

This guide explains the security policies, IAM configurations, and compliance features in our GKE Terraform setup. These configurations implement defense-in-depth security principles and compliance requirements.

## Service Account Security & Permissions

### Minimal Privilege Service Account Strategy

```hcl
node_group_service_account_roles = [
  "roles/logging.logWriter",           # Write logs to Cloud Logging
  "roles/monitoring.metricWriter",     # Send metrics to Cloud Monitoring
  "roles/monitoring.viewer",           # Read monitoring data
  "roles/stackdriver.resourceMetadata.writer", # Write resource metadata
  "roles/container.nodeServiceAccount" # Basic GKE node operations
]
```

**Why minimal permissions matter**:
- **Blast radius limitation**: If a node is compromised, the attacker has limited access
- **Compliance**: Many frameworks require least privilege access
- **Audit clarity**: Easier to audit when permissions are explicit and minimal

**Each role explanation**:
1. **logging.logWriter**: Allows writing application and system logs
2. **monitoring.metricWriter**: Enables sending custom metrics and health data
3. **monitoring.viewer**: Required for some monitoring agents to read metadata
4. **stackdriver.resourceMetadata.writer**: Allows associating metrics with resources
5. **container.nodeServiceAccount**: Basic permissions for GKE node operations

### OAuth Scopes Security

```hcl
node_group_oauth_scopes = [
  "https://www.googleapis.com/auth/logging.write",
  "https://www.googleapis.com/auth/monitoring",
  "https://www.googleapis.com/auth/devstorage.read_only",  # Read-only registry access
  "https://www.googleapis.com/auth/servicecontrol",
  "https://www.googleapis.com/auth/service.management.readonly",
  "https://www.googleapis.com/auth/trace.append"
]
```

**OAuth scopes vs IAM roles**:
- **OAuth scopes**: API-level permissions that limit what tokens can access
- **IAM roles**: Resource-level permissions that define what actions are allowed
- **Both required**: OAuth scopes provide an additional security boundary

**Why read-only storage access**:
- **Container registry**: Nodes need to pull container images
- **No write access**: Prevents nodes from modifying or uploading containers
- **Security boundary**: Even if compromised, nodes cannot inject malicious images

## Binary Authorization for Container Security

### Policy-Based Image Admission

```hcl
enable_binary_authorization = var.enable_binary_authorization
```

**When to enable Binary Authorization**:
- **High-security environments**: Financial services, healthcare, government
- **Compliance requirements**: FIPS, FedRAMP, SOC 2 Type II
- **Supply chain security**: Need to verify container image provenance

**How Binary Authorization works**:
1. **Image scanning**: Container images are scanned for vulnerabilities
2. **Attestation**: Trusted systems create cryptographic attestations
3. **Policy evaluation**: Admission controller checks policies before deployment
4. **Enforcement**: Only compliant images are allowed to run

**Implementation considerations**:
```yaml
# Example Binary Authorization policy
apiVersion: binaryauthorization.grafeas.io/v1beta1
kind: Policy
metadata:
  name: my-policy
spec:
  defaultAdmissionRule:
    requireAttestationsBy:
    - projects/PROJECT_ID/attestors/prod-attestor
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
```

## Database Encryption at Rest

### Customer-Managed Encryption Keys (CMEK)

```hcl
dynamic "database_encryption" {
  for_each = var.database_encryption_key_name != "" ? [1] : []
  content {
    state    = "ENCRYPTED"
    key_name = var.database_encryption_key_name
  }
}
```

**What gets encrypted with CMEK**:
- **Kubernetes secrets**: Application secrets and TLS certificates
- **ConfigMaps**: Application configuration data
- **etcd data**: All Kubernetes state information

**CMEK vs Google-managed encryption**:
- **Control**: You control key rotation and access policies
- **Compliance**: Meet requirements for customer-controlled encryption
- **Auditability**: All key usage is logged in Cloud Audit Logs
- **Complexity**: Requires additional key management operations

**Key management best practices**:
```hcl
# Example KMS key configuration
resource "google_kms_crypto_key" "gke_key" {
  name     = "gke-database-encryption"
  key_ring = google_kms_key_ring.gke_ring.id
  purpose  = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }

  rotation_period = "7776000s"  # 90 days
}
```

## Network Policies and Microsegmentation

### Calico Network Policy Engine

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

**Why Calico over basic Kubernetes NetworkPolicy**:
- **Global policies**: Apply policies across all namespaces
- **Host endpoint policies**: Control traffic to/from nodes themselves
- **Advanced selectors**: More flexible matching criteria
- **Performance**: Better performance for large clusters

### Network Policy Strategy

**Default-deny approach**:
```yaml
# Deny all traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: production
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```

**Service-to-service communication**:
```yaml
# Allow specific communication paths
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
    ports:
    - protocol: TCP
      port: 8080
```

## Workload Identity for Pod Authentication

### Secure Pod-to-GCP Authentication

```hcl
workload_identity_config {
  workload_pool = "${var.project_id}.svc.id.goog"
}
```

**Traditional vs Workload Identity authentication**:

**Traditional approach (insecure)**:
1. Download service account key file
2. Mount key as Kubernetes secret
3. Application reads key from filesystem
4. Long-lived credentials stored in cluster

**Workload Identity approach (secure)**:
1. Kubernetes service account bound to Google service account
2. Pod requests token from metadata server
3. Google issues short-lived token
4. Token automatically rotated

**Implementation example**:
```yaml
# Kubernetes service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  annotations:
    iam.gke.io/gcp-service-account: my-app@PROJECT_ID.iam.gserviceaccount.com
```

```bash
# Bind Kubernetes SA to Google SA
gcloud iam service-accounts add-iam-policy-binding \
  my-app@PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT_ID.svc.id.goog[NAMESPACE/my-app]"
```

## Pod Security Standards

### Pod Security Admission Configuration

```yaml
# Namespace-level pod security enforcement
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Pod Security Standard levels**:
- **Privileged**: No restrictions (only for system workloads)
- **Baseline**: Minimal restrictions preventing known privilege escalations
- **Restricted**: Heavily restricted, following current pod hardening best practices

**Restricted standard requirements**:
- Non-root containers
- No privileged containers
- Read-only root filesystem
- No host network/PID/IPC access
- Seccomp profiles applied
- Capabilities dropped

## RBAC (Role-Based Access Control)

### Principle of Least Privilege RBAC

```yaml
# Example restrictive RBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: my-app
  name: app-reader
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
```

**RBAC best practices**:
1. **Start with read-only**: Begin with minimal permissions and add as needed
2. **Namespace isolation**: Use roles instead of cluster roles when possible
3. **Service account binding**: Bind roles to service accounts, not users when possible
4. **Regular audits**: Review and cleanup unused RBAC rules

## Security Monitoring and Compliance

### Resource Labeling for Security

```hcl
resource_labels = merge(var.labels, {
  cluster_name = var.name
  managed_by   = "terraform"
  component    = "gke_cluster"
  environment  = "gke"
  security_tier = "hardened"
})
```

**Security-focused labeling strategy**:
- **security_tier**: Classification level (hardened, standard, development)
- **compliance_scope**: Regulatory frameworks that apply (pci, hipaa, sox)
- **data_classification**: Sensitivity level of data processed
- **incident_contact**: Team responsible for security incidents

### Audit Logging Configuration

```hcl
# Comprehensive audit logging is enabled by default in GKE
# Additional configuration for specific compliance needs:

cluster_telemetry {
  type = "ENABLED"  # Required for some compliance frameworks
}
```

**Audit log categories automatically enabled**:
- **Admin Activity**: Administrative actions (always enabled)
- **Data Access**: Access to user data (configurable)
- **System Events**: System-generated events
- **Policy Violations**: Binary Authorization and other policy violations

## Compliance Framework Alignment

### Common Compliance Requirements

**FIPS 140-2 Level 1**:
- ✅ FIPS-validated cryptography for data in transit and at rest
- ✅ Secure boot with Shielded VMs
- ✅ Container image validation with Binary Authorization

**SOC 2 Type II**:
- ✅ Access controls with RBAC and Workload Identity
- ✅ Audit logging with Cloud Audit Logs
- ✅ Data encryption with customer-managed keys

**PCI DSS**:
- ✅ Network segmentation with network policies
- ✅ Access controls with IAM and RBAC
- ✅ Encryption in transit and at rest

**HIPAA**:
- ✅ Access controls and audit logging
- ✅ Encryption with customer-managed keys
- ✅ Network isolation with private clusters

## Key Security Policy Takeaways

1. **Defense in Depth**: Multiple security layers working together

2. **Zero Trust**: Never trust, always verify with comprehensive policies

3. **Least Privilege**: Minimal permissions at all levels (IAM, RBAC, network)

4. **Compliance Ready**: Configurations meet common regulatory requirements

5. **Continuous Monitoring**: Comprehensive logging and audit trails

6. **Operational Security**: Clear policies for key management and access control

This security policy configuration establishes a foundation that meets enterprise security requirements while maintaining operational flexibility.

---

## Technical Reference

For detailed technical specifications, variables, and outputs, see the [auto-generated documentation](policies.md).
