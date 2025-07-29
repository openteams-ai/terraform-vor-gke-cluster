<!-- BEGINNING OF PRE-COMMIT-TERRAFORM-DOCS HOOK -->
<!-- This section will be automatically populated by terraform-docs -->
<!-- END OF PRE-COMMIT-TERRAFORM-DOCS HOOK -->

<!-- BEGIN_TF_DOCS -->
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

## ⚡ Quick Reference

| Variable             | Type     | Description                                      |
| -------------------- | -------- | ------------------------------------------------ |
| `name`               | `string` | Name of the GKE cluster and associated resources |
| `location`           | `string` | GCP zone where the cluster will be created       |
| `region`             | `string` | GCP region for regional resources                |
| `project_id`         | `string` | GCP project ID where resources will be created   |
| `kubernetes_version` | `string` | Kubernetes version for the cluster               |

**📖 [Complete Variable Reference](docs/components/)** - Detailed documentation for all variables and configuration options

## 🏷️ Resource Labeling

All infrastructure resources are automatically labeled for tracking, cost allocation, and management. You can add custom labels that will be merged with the standard ones.

**📖 [Complete Labeling Guide](.labeling-conventions.md)** - Detailed labeling conventions and best practices

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 5.0 |
## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 5.0 |
## Modules

No modules.
## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.allow_health_checks](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.deny_all_ingress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_network.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_project_iam_member.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.container](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_node_group_oauth_scopes"></a> [additional\_node\_group\_oauth\_scopes](#input\_additional\_node\_group\_oauth\_scopes) | Additional OAuth scopes for nodes | `list(string)` | `[]` | no |
| <a name="input_additional_node_group_roles"></a> [additional\_node\_group\_roles](#input\_additional\_node\_group\_roles) | Additional IAM roles for node service account | `list(string)` | `[]` | no |
| <a name="input_authorized_networks"></a> [authorized\_networks](#input\_authorized\_networks) | List of authorized networks that can access the cluster master | <pre>list(object({<br/>    cidr_block   = string<br/>    display_name = string<br/>  }))</pre> | `[]` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of zones where nodes can be created | `list(string)` | `[]` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Whether to create a new VPC or use existing network resources | `bool` | `true` | no |
| <a name="input_database_encryption_key_name"></a> [database\_encryption\_key\_name](#input\_database\_encryption\_key\_name) | KMS key name for database encryption at rest | `string` | `""` | no |
| <a name="input_enable_binary_authorization"></a> [enable\_binary\_authorization](#input\_enable\_binary\_authorization) | Enable binary authorization for container image security | `bool` | `false` | no |
| <a name="input_enable_private_endpoint"></a> [enable\_private\_endpoint](#input\_enable\_private\_endpoint) | Enable private endpoint for the cluster master (nodes are always private) | `bool` | `false` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version for the cluster | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to all node pools | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | GCP zone where the cluster will be created | `string` | n/a | yes |
| <a name="input_maintenance_start_time"></a> [maintenance\_start\_time](#input\_maintenance\_start\_time) | Start time for daily maintenance window (HH:MM format) | `string` | `"02:00"` | no |
| <a name="input_master_ipv4_cidr_block"></a> [master\_ipv4\_cidr\_block](#input\_master\_ipv4\_cidr\_block) | CIDR block for the master network | `string` | `"172.16.0.0/28"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the GKE cluster and associated resources | `string` | n/a | yes |
| <a name="input_network_self_link"></a> [network\_self\_link](#input\_network\_self\_link) | Self link of existing VPC network (when create\_vpc is false) | `string` | `""` | no |
| <a name="input_node_disk_size_gb"></a> [node\_disk\_size\_gb](#input\_node\_disk\_size\_gb) | Disk size for node pools in GB | `number` | `100` | no |
| <a name="input_node_disk_type"></a> [node\_disk\_type](#input\_node\_disk\_type) | Disk type for node pools | `string` | `"pd-balanced"` | no |
| <a name="input_node_group_defaults"></a> [node\_group\_defaults](#input\_node\_group\_defaults) | Default values for node groups | <pre>object({<br/>    min_size      = number<br/>    max_size      = number<br/>    instance_type = string<br/>    preemptible   = optional(bool, false)<br/>    node_taints = optional(list(object({<br/>      key    = string<br/>      value  = string<br/>      effect = string<br/>    })), [])<br/>    guest_accelerators = optional(list(object({<br/>      name               = string<br/>      count              = number<br/>      gpu_partition_size = optional(string, "")<br/>    })), [])<br/>    labels = optional(map(string), {})<br/>  })</pre> | <pre>{<br/>  "guest_accelerators": [],<br/>  "instance_type": "e2-standard-2",<br/>  "labels": {},<br/>  "max_size": 3,<br/>  "min_size": 1,<br/>  "node_taints": [],<br/>  "preemptible": false<br/>}</pre> | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | List of node pool configurations | <pre>list(object({<br/>    name          = string<br/>    min_size      = number<br/>    max_size      = number<br/>    instance_type = string<br/>    preemptible   = optional(bool, false)<br/>    node_taints = optional(list(object({<br/>      key    = string<br/>      value  = string<br/>      effect = string<br/>    })), [])<br/>    guest_accelerators = optional(list(object({<br/>      name               = string<br/>      count              = number<br/>      gpu_partition_size = optional(string, "")<br/>      gpu_driver_version = optional(string, "")<br/>    })), [])<br/>    labels = optional(map(string), {})<br/>  }))</pre> | <pre>[<br/>  {<br/>    "guest_accelerators": [],<br/>    "instance_type": "e2-standard-2",<br/>    "labels": {},<br/>    "max_size": 3,<br/>    "min_size": 1,<br/>    "name": "default",<br/>    "node_taints": [],<br/>    "preemptible": false<br/>  }<br/>]</pre> | no |
| <a name="input_pods_secondary_range_name"></a> [pods\_secondary\_range\_name](#input\_pods\_secondary\_range\_name) | Name of secondary range for pods (when using existing VPC) | `string` | `""` | no |
| <a name="input_pods_subnet_cidr"></a> [pods\_subnet\_cidr](#input\_pods\_subnet\_cidr) | CIDR range for pods secondary subnet | `string` | `"10.1.0.0/16"` | no |
| <a name="input_primary_subnet_cidr"></a> [primary\_subnet\_cidr](#input\_primary\_subnet\_cidr) | CIDR range for the primary subnet | `string` | `"10.0.0.0/24"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID where resources will be created | `string` | n/a | yes |
| <a name="input_rbac_security_group"></a> [rbac\_security\_group](#input\_rbac\_security\_group) | Security group for RBAC authenticator | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region for regional resources | `string` | n/a | yes |
| <a name="input_release_channel"></a> [release\_channel](#input\_release\_channel) | GKE release channel | `string` | `"STABLE"` | no |
| <a name="input_services_secondary_range_name"></a> [services\_secondary\_range\_name](#input\_services\_secondary\_range\_name) | Name of secondary range for services (when using existing VPC) | `string` | `""` | no |
| <a name="input_services_subnet_cidr"></a> [services\_subnet\_cidr](#input\_services\_subnet\_cidr) | CIDR range for services secondary subnet | `string` | `"10.2.0.0/16"` | no |
| <a name="input_subnetwork_self_link"></a> [subnetwork\_self\_link](#input\_subnetwork\_self\_link) | Self link of existing subnetwork (when create\_vpc is false) | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Network tags for node pools | `list(string)` | `[]` | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | Base64 encoded cluster CA certificate |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint for the GKE cluster |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the GKE cluster |
| <a name="output_cluster_security_features"></a> [cluster\_security\_features](#output\_cluster\_security\_features) | Security features enabled on the cluster |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig for connecting to kubernetes cluster |
| <a name="output_node_pools"></a> [node\_pools](#output\_node\_pools) | List of node pool names |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the service account used by node pools |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | ID of the subnet |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC network |

## Contributing

Please read the contribution guidelines before submitting changes. All source code files must include appropriate copyright headers - see [COPYRIGHT.md](COPYRIGHT.md) for details.

## License

This module is licensed under the Apache 2.0 License. See [LICENSE](LICENSE) for details.
<!-- END_TF_DOCS -->