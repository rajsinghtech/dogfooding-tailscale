# Azure Performance Testing Module

This Terraform module creates a set of Azure VMs for performance testing, configured with Tailscale and iperf3. The VMs are placed in a proximity placement group for optimal network performance.

## Features

- Creates a resource group, virtual network, and subnet
- Deploys multiple VMs in a proximity placement group
- Configures Tailscale for secure networking
- Installs and configures iperf3 for network performance testing
- Applies Azure network optimizations
- Configures security group rules for required ports

## Usage

```hcl
module "perf_testing" {
  source = "../azure-ts-perf-testing"

  tenant       = "your-tenant"
  environment = "dev"
  stage       = "test"
  location    = "eastus"

  ssh_public_key_path  = "~/.ssh/id_rsa.pub"
  ssh_private_key_path = "~/.ssh/id_rsa"
  
  tailscale_auth_key = "tskey-xxxxxxxxx"
  tailscale_tags     = ["perf-testing"]
  
  # Optional: Override default VM size
  vm_size = "Standard_D4s_v3"
  
  # Optional: Override default instance count (default: 2)
  instance_count = 2
  
  tags = {
    Environment = "test"
    ManagedBy   = "terraform"
  }
}

# Outputs
output "ssh_commands" {
  value = module.perf_testing.ssh_commands
}

output "iperf_server_command" {
  value = module.perf_testing.iperf_server_command
}

output "iperf_client_command" {
  value = module.perf_testing.iperf_client_command
}
```

## Requirements

- Terraform >= 1.0
- Azure Provider >= 3.0
- Tailscale Provider >= 0.13
- An existing Tailscale auth key with appropriate permissions

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| tenant | Name of the user/tenant for the Atmos Stack | `string` | n/a | yes |
| environment | Short-form name of the environment | `string` | n/a | yes |
| stage | Name of stage | `string` | n/a | yes |
| location | Azure region for deployment | `string` | n/a | yes |
| ssh_public_key_path | Path to the public SSH key for VM access | `string` | n/a | yes |
| ssh_private_key_path | Path to the private SSH key | `string` | n/a | yes |
| tailscale_auth_key | Tailscale auth key | `string` | n/a | yes |
| vnet_cidr | CIDR block for the VNet | `string` | `"10.0.0.0/16"` | no |
| subnet_cidr | CIDR block for the subnet | `string` | `"10.0.1.0/24"` | no |
| vm_size | VM size for performance testing instances | `string` | `"Standard_D4s_v3"` | no |
| instance_count | Number of instances to create | `number` | `2` | no |
| admin_username | Admin username for the VMs | `string` | `"azureuser"` | no |
| tailscale_tags | List of tags to apply to Tailscale node | `list(string)` | `["perf-testing"]` | no |
| enable_accelerated_networking | Enable accelerated networking for the VMs | `bool` | `true` | no |
| os_disk_size_gb | Size of the OS disk in GB | `number` | `64` | no |
| os_disk_type | Type of OS disk | `string` | `"StandardSSD_LRS"` | no |

## Outputs

| Name | Description |
|------|-------------|
| resource_group_name | The name of the resource group |
| vnet_name | The name of the virtual network |
| subnet_name | The name of the subnet |
| vm_public_ips | Map of VM names to public IP addresses |
| ssh_commands | SSH commands to connect to the instances |
| iperf_server_command | Command to start an iperf3 server on the first instance |
| iperf_client_command | Command to run an iperf3 client test from the second instance to the first |
| proximity_placement_group_id | The ID of the proximity placement group |
| vm_ids | Map of VM names to their IDs |

## Running Performance Tests

After deploying the infrastructure, you can run performance tests between the instances:

1. On the first VM (server), start the iperf3 server:

   ```bash
   iperf3 -s
   ```

2. On the second VM (client), run the iperf3 client to test the connection:

   ```bash
   iperf3 -i 0 -c $TARGET_IP -t 10 -C cubic -V
   ```
