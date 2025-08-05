# google-gke-dpv2

Google Kubernetes Engine (GKE) with Dataplane V2 and Tailscale subnet router.

## Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `project_id` | string | The Google Cloud project ID to deploy to | - |
| `name` | string | Name for all resources | - |
| `region` | string | The Google Cloud region to deploy to | - |
| `zone` | string | The Google Cloud zone to deploy to | - |
| `enable_endpoint_independent_mapping` | bool | Enable endpoint independent mapping aka easy NAT | `true` |
| `machine_type` | string | The machine type to use for GKE nodes | - |
| `node_count` | number | Number of nodes in the GKE node pool | - |
| `ssh_public_keys` | list(string) | List of SSH public keys in format 'username:publickey' for VM access | - |
| `service_account` | string | Service account email for GKE nodes | `""` |
| `authorized_networks` | list(object) | List of CIDR blocks that can access the Kubernetes API | - |
| `enable_sr` | bool | Enable subnet router functionality | - |
| `advertise_routes` | list(string) | Additional CIDR blocks to advertise to Tailscale (VPC subnets included automatically) | `[]` |
| `vpc_subnet_cidr` | string | CIDR range for the main VPC subnet | - |
| `gke_subnet_cidr` | string | CIDR range for the GKE subnet | - |
| `gke_pod_range_cidr` | string | CIDR range for GKE pods | - |
| `gke_service_range_cidr` | string | CIDR range for GKE services | - |
| `gke_master_cidr` | string | CIDR range for GKE control plane nodes (must be /28 range) | - |
| `tenant` | string | The tenant name for the cluster | `sales` |
| `environment` | string | The environment name for the cluster | `sandbox` |
| `stage` | string | The stage name for the cluster | `test` |
| `oauth_client_id` | string | The OAuth client ID for the cluster | - |
| `oauth_client_secret` | string | The OAuth client secret for the cluster | - |
| `tags` | map(string) | A map of tags to add to all resources | - |
| `kubelet_config` | object | Kubelet configuration options | `{}` |
| `tailscale_track` | string | Tailscale client version: `stable` or `unstable` | `stable` |
| `tailscale_relay_server_port` | number | Port for Tailscale peer relay server (1024-65535, unstable track only) | `null` |

### Authorized Networks Object

```
[{
  name = "my-network"
  cidr = "1.2.3.4/32"
}]
```

### Kubelet Config Object

```
{
  cpu_manager_policy   = optional(string)
  cpu_cfs_quota        = optional(bool)
  cpu_cfs_quota_period = optional(string)
  pod_pids_limit       = optional(number)
}
```