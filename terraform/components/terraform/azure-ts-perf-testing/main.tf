# Provider configurations
provider "azurerm" {
  features {}
}

provider "tailscale" {
  # OAuth credentials will be provided by the parent module
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret
}

# Create a resource group
resource "azurerm_resource_group" "main" {
  name     = format("%s-%s-%s-perf-test-rg", var.tenant, var.environment, var.stage)
  location = var.location
  tags     = merge(var.tags, {
    Region        = var.location
    Tenant = var.tenant
    Env           = var.environment
    Stage         = var.stage
  })
}

# Get current public IP for NSG rule
data "http" "my_public_ip" {
  url = "https://ipinfo.io/ip"
}

# Create a virtual network
resource "azurerm_virtual_network" "main" {
  name                = format("%s-%s-%s-vnet", var.tenant, var.environment, var.stage)
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = merge(var.tags, {
    Region        = var.location
    Tenant = var.tenant
    Env           = var.environment
    Stage         = var.stage
  })
}

# Create a subnet
resource "azurerm_subnet" "main" {
  name                 = format("%s-%s-%s-public-0", var.tenant, var.environment, var.stage)
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

# Create a public IP for each VM
resource "azurerm_public_ip" "vm" {
  count               = var.instance_count
  name                = format("%s-%s-%s-vm%d-pip", var.tenant, var.environment, var.stage, count.index + 1)
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = merge(var.tags, {
    Region = var.location
    Tenant = var.tenant
    Env    = var.environment
    Stage  = var.stage
  })
}

# Create a single network security group for all VMs
resource "azurerm_network_security_group" "main" {
  name                = format("%s-%s-%s-perf-nsg", var.tenant, var.environment, var.stage)
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = merge(var.tags, {
    Region = var.location
    Tenant = var.tenant
    Env    = var.environment
    Stage  = var.stage
  })

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Tailscale"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "41641"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "iperf3"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5201"
    source_address_prefixes    = [var.vnet_cidr]
    destination_address_prefix = "*"
    description               = "Allow iperf3 traffic within VPC"
  }

  security_rule {
    name                       = "iperf3-wan"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5201"
    source_address_prefix      = format("%s/32", chomp(data.http.my_public_ip.response_body))
    destination_address_prefix = "*"
    description               = "Allow iperf3 traffic from my public IP for WAN testing"
  }

  dynamic "security_rule" {
    for_each = var.tailscale_relay_server_port != null ? [1] : []
    content {
      name                       = "TailscaleRelay"
      priority                   = 140
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(var.tailscale_relay_server_port)
      source_address_prefix      = "0.0.0.0/0"
      destination_address_prefix = "*"
      description               = "Allow Tailscale relay server traffic"
    }
  }
}

# Create a network interface for each VM
resource "azurerm_network_interface" "vm" {
  count                          = var.instance_count
  name                           = format("%s-%s-%s-vm%d-nic", var.tenant, var.environment, var.stage, count.index + 1)
  location                       = azurerm_resource_group.main.location
  resource_group_name            = azurerm_resource_group.main.name
  accelerated_networking_enabled = var.enable_accelerated_networking
  tags = merge(var.tags, {
    Region = var.location
    Tenant = var.tenant
    Env    = var.environment
    Stage  = var.stage
  })

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm[count.index].id
  }
}

# Associate NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Create a proximity placement group
resource "azurerm_proximity_placement_group" "main" {
  name                = format("%s-%s-%s-ppg", var.tenant, var.environment, var.stage)
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = merge(var.tags, {
    Region = var.location
    Tenant = var.tenant
    Env    = var.environment
    Stage  = var.stage
  })
}

# Script to install iperf3
locals {
  iperf3_install_script = <<-EOT
    #!/bin/bash
    set -e
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y iperf3
  EOT
}

# Use the cloudinit-ts module to install and configure Tailscale
module "cloudinit_ts" {
  source = "../modules/cloudinit-ts"
  count  = var.instance_count

  providers = {
    tailscale = tailscale
  }

  hostname            = format("%s-%s-%s-vm%d", var.tenant, var.environment, var.stage, count.index + 1)
  accept_routes       = true
  enable_ssh          = true
  primary_tag         = "infra"
  reusable            = true
  ephemeral           = false
  track               = var.tailscale_track
  relay_server_port   = var.tailscale_relay_server_port

  additional_parts = [
    {
      filename     = "install_iperf3.sh"
      content_type = "text/x-shellscript"
      content      = local.iperf3_install_script
    },
    {
      filename     = "copy_network_script.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOT
        #!/bin/bash
        set -e
        mkdir -p /opt/scripts
        cat > /opt/scripts/azure-network-optimize.sh <<'EOF'
        ${file("${path.module}/files/azure-network-optimize.sh")}
        EOF
        chmod +x /opt/scripts/azure-network-optimize.sh
      EOT
    }
  ]
}

# Create VMs
resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.instance_count
  name                            = format("%s-%s-%s-vm%d", var.tenant, var.environment, var.stage, count.index + 1)
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  proximity_placement_group_id    = azurerm_proximity_placement_group.main.id
  network_interface_ids = [
    azurerm_network_interface.vm[count.index].id
  ]
  tags = merge(var.tags, {
    Region = var.location
    Tenant = var.tenant
    Env    = var.environment
    Stage  = var.stage
  })

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = format("%s-%s-%s-vm%d-osdisk", var.tenant, var.environment, var.stage, count.index + 1)
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.source_image_reference.publisher
    offer     = var.source_image_reference.offer
    sku       = var.source_image_reference.sku
    version   = var.source_image_reference.version
  }

  # Use the cloud-init config from the module
  custom_data = module.cloudinit_ts[count.index].rendered
}
