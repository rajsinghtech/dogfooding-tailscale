# azure-ts-perf-testing

Azure VMs for Tailscale performance testing.

## Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `tenant` | string | Name of the user/tenant for the Atmos Stack | - |
| `environment` | string | Short-form name of the region for the Atmos Stack | - |
| `stage` | string | Name of stage | - |
| `location` | string | Azure region for deployment | - |
| `ssh_public_key_path` | string | Path to the public SSH key to use for VM access | - |
| `ssh_private_key_path` | string | Path to the private SSH key for remote provisioner and SSH access | - |
| `tags` | map(string) | Map of tags to assign to resources | - |
| `vnet_cidr` | string | Azure VNet CIDR | - |
| `subnet_cidr` | string | Azure Subnet CIDR | - |
| `vm_size` | string | VM size for performance testing instances | - |
| `instance_count` | number | Number of instances to create | `2` |
| `admin_username` | string | Admin username for the VMs | `ubuntu` |
| `oauth_client_id` | string | OAuth client ID for Tailscale (sensitive) | - |
| `oauth_client_secret` | string | OAuth client secret for Tailscale (sensitive) | - |
| `enable_accelerated_networking` | bool | Enable accelerated networking for the VMs | `true` |
| `os_disk_size_gb` | number | Size of the OS disk in GB | `30` |
| `os_disk_type` | string | Type of OS disk | `StandardSSD_LRS` |
| `source_image_reference` | object | Source image reference for the VMs | Ubuntu 24.04 LTS Server |
| `tailscale_track` | string | Tailscale client version: `stable` or `unstable` | `stable` |
| `tailscale_relay_server_port` | number | Port for Tailscale peer relay server (1024-65535, unstable track only) | `null` |

### Source Image Reference Object

Default:
```
{
  publisher = "Canonical"
  offer     = "ubuntu-24_04-lts"
  sku       = "server"
  version   = "latest"
}
```
