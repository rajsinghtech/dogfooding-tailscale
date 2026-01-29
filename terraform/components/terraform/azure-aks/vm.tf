# Use the same cloudinit-ts module as AWS for Tailscale setup
module "ubuntu-tailscale-client" {
  count             = local.enable_sr ? local.sr_vmss_desired_size : 0
  source            = "../modules/cloudinit-ts"
  hostname          = "${local.hostname}-${count.index + 1}"
  accept_routes     = var.sr_accept_routes
  enable_ssh        = var.sr_enable_ssh
  ephemeral         = var.sr_ephemeral
  reusable          = var.sr_reusable
  advertise_routes  = local.advertise_routes
  primary_tag       = var.sr_primary_tag
  track             = var.tailscale_track
  relay_server_port = var.tailscale_relay_server_port
}

resource "azurerm_network_security_group" "vmss" {
  count               = local.enable_sr ? 1 : 0
  name                = format("%s-%s-%s-%s-vmss-nsg", local.tenant, local.environment, local.stage, local.hostname)
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Allow SSH access"
  }

  security_rule {
    name                       = "TailscaleWG"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "41641"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Allow Tailscale WG direct connection access"
  }

  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 1003
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Allow all outbound traffic"
  }

  dynamic "security_rule" {
    for_each = var.tailscale_relay_server_port != null ? [1] : []
    content {
      name                       = "TailscaleRelay"
      priority                   = 1004
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Udp"
      source_port_range          = "*"
      destination_port_range     = tostring(var.tailscale_relay_server_port)
      source_address_prefix      = "0.0.0.0/0"
      destination_address_prefix = "*"
      description                = "Allow Tailscale relay server traffic"
    }
  }

  tags = local.tags
}

resource "azurerm_linux_virtual_machine_scale_set" "sr" {
  #checkov:skip=CKV_AZURE_97:Encryption at host not needed for lab environment
  count                           = local.enable_sr ? 1 : 0
  name                            = format("%s-%s-%s-%s-sr-vmss", local.tenant, local.environment, local.stage, local.hostname)
  location                        = local.location
  resource_group_name             = azurerm_resource_group.main.name
  sku                             = local.vm_size
  instances                       = local.sr_vmss_desired_size
  admin_username                  = "ubuntu"
  disable_password_authentication = true
  custom_data                     = element(module.ubuntu-tailscale-client[*].rendered, 0)

  admin_ssh_key {
    username   = "ubuntu"
    public_key = file(var.ssh_public_key_path)
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name                      = "sr-nic"
    primary                   = true
    enable_ip_forwarding      = true
    network_security_group_id = azurerm_network_security_group.vmss[0].id

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.public[0].id
      public_ip_address {
        name = "sr-pip"
      }
    }
  }

  tags = merge(
    local.tags,
    {
      "Name" = local.hostname
    }
  )
}
