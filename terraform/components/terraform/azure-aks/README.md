# azure-aks

Azure Kubernetes Service (AKS) deployment with Tailscale integration.

## Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `tenant` | string | Name of the user/tenant for the Atmos Stack | - |
| `environment` | string | Short-form name of the region for the Atmos Stack | - |
| `stage` | string | Name of stage | - |
| `cluster_name` | string | Name of cluster | - |
| `location` | string | Azure region for deployment | - |
| `ssh_public_key_path` | string | Path to the public SSH key to use for VM access | - |
| `ssh_private_key_path` | string | Path to the private SSH key for remote provisioner and SSH access | - |
| `tags` | map(string) | Map of tags to assign to resources | `{}` |
| `vnet_cidr` | string | Azure VNet CIDR | - |
| `aks_service_ipv4_cidr` | string | Kubernetes Service CIDR | - |
| `cluster_vm_size` | string | VM size for AKS node pool | - |
| `vm_size` | string | VM size for Tailscale VM | - |
| `aks_version` | string | Kubernetes version for this cluster | - |
| `min_count` | string | Minimum number of cluster nodes | - |
| `node_count` | string | Number of cluster nodes | - |
| `max_count` | string | Maximum number of cluster nodes | - |
| `cluster_outbound_type` | string | Outbound type: `userAssignedNATGateway` (hard NAT) or `loadBalancer` (easy NAT) | - |
| `oauth_client_id` | string | OAuth application's ID (sensitive, can use TAILSCALE_OAUTH_CLIENT_ID env var) | - |
| `oauth_client_secret` | string | OAuth application's secret (sensitive, can use TAILSCALE_OAUTH_CLIENT_SECRET env var) | - |
| `hostname` | string | Tailscale Machine hostname of the VM instance | - |
| `advertise_routes` | list(string) | CIDR blocks to advertise via Tailscale in addition to AKS private subnets | `[]` |
| `tailscale_track` | string | Tailscale client version: `stable` or `unstable` | `stable` |
| `tailscale_relay_server_port` | number | Port for Tailscale peer relay server (1024-65535, unstable track only) | `null` |