# Vor Terraform - Secure GKE Infrastructure Module

This Terraform module creates a security-hardened Google Kubernetes Engine (GKE) cluster with customizable node pools, custom VPC networking, and comprehensive IAM configurations following least privilege principles.

## 🏗️ Architecture Overview

The module creates a complete secure GKE environment with:
- Private GKE cluster with enhanced security configurations
- Custom VPC with dedicated subnets and secondary IP ranges
- Private node pools with shielded VMs and secure boot
- Dedicated service accounts with minimal required permissions
- Network policies and firewall rules for secure communication
- NAT Gateway for secure outbound internet access from private nodes

## 📚 Deep Dive Documentation

- [🌐 Network security architecture](docs/components/network-header.md) | [📋 Technical Reference](docs/components/network.md)
- [🔐 IAM and security policies](docs/components/policies-header.md) | [📋 Technical Reference](docs/components/policies.md)
- [⚙️ GKE cluster configuration](docs/components/cluster-header.md) | [📋 Technical Reference](docs/components/cluster.md)
- [🖥️ Node pool security](docs/components/nodes-header.md) | [📋 Technical Reference](docs/components/nodes.md)

## Infrastructure Overview (Layout)

```mermaid
graph TD
  subgraph GCP Project
    VPC["Custom VPC (create_vpc=true)"]
    SubnetPrimary["Primary Subnet (10.0.0.0/24)"]
    SubnetPods["Pods Subnet (10.1.0.0/16)"]
    SubnetServices["Services Subnet (10.2.0.0/16)"]
    NAT["Cloud NAT Gateway"]
    FlowLogs["VPC Flow Logs"]
  end

  subgraph GKE Cluster
    Cluster["Private GKE Cluster\n(Private Nodes, No Public IP)"]
    Master["Master Node\n(API Server, Private Endpoint)"]
    MasterCIDR["Master CIDR: 172.16.0.0/28"]
    WorkloadID["Workload Identity"]
    BinaryAuth["Binary Authorization"]
    NetworkPolicies["Network Policies (Calico)"]
    Firewall["Firewall Rules\n(Deny-All-Ingress by Default)"]
  end

  subgraph Node Pools
    SecureNodes["Node Pool: secure-nodes\ne2-standard-4"]
    General["Node Pool: general\ne2-standard-4"]
    Compute["Node Pool: compute-optimized\nc2-standard-8, Preemptible"]
    GPU["Node Pool: gpu-nodes\nn1-standard-4 + T4 GPU"]
    ShieldedVMs["Shielded VMs\nSecure Boot + Integrity Monitoring"]
    Taints["Node Taints"]
    Accelerators["Guest Accelerators\n(NVIDIA T4)"]
  end

  subgraph IAM
    SANode["Node Pool Service Account\nLeast Privilege"]
    IAMRoles["IAM Roles\n(logWriter, metricWriter, etc)"]
    OAuthScopes["OAuth Scopes\n(logging, monitoring, etc)"]
  end

  subgraph Security & Monitoring
    Monitoring["Monitoring + Logging"]
  end

  %% VPC connectivity
  VPC --> SubnetPrimary
  VPC --> SubnetPods
  VPC --> SubnetServices
  VPC --> NAT
  VPC --> FlowLogs

  %% Cluster and Master
  SubnetPrimary --> Cluster
  SubnetPrimary --> Master
  Master --> MasterCIDR
  Cluster --> WorkloadID
  Cluster --> BinaryAuth
  Cluster --> NetworkPolicies
  Cluster --> Firewall

  %% Node Pools inside cluster
  Cluster --> SecureNodes
  Cluster --> General
  Cluster --> Compute
  Cluster --> GPU

  %% Node security
  SecureNodes --> ShieldedVMs
  General --> ShieldedVMs
  Compute --> ShieldedVMs
  GPU --> ShieldedVMs
  GPU --> Accelerators
  GPU --> Taints
  Compute --> Taints

  %% IAM bindings
  Cluster --> SANode
  SecureNodes --> SANode
  General --> SANode
  Compute --> SANode
  GPU --> SANode
  SANode --> IAMRoles
  SANode --> OAuthScopes

  %% Monitoring
  Cluster --> Monitoring
  FlowLogs --> Monitoring
```

## 🚀 Getting Started

1. **Review the Examples**: Start with the [basic example](examples/basic/) for a simple setup or the [advanced example](examples/advanced/) for a production-ready configuration
2. **Configure Variables**: See the complete inputs documentation below for all configuration options
3. **Deploy**: Run `terraform init`, `terraform plan`, and `terraform apply`

For detailed configuration guides, see the component documentation linked above.
