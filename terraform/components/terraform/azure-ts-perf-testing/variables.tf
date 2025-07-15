variable "tenant" {
  description = "Name of the user/tenant for the Atmos Stack"
  type        = string
}

variable "environment" {
  description = "Short-form name of the region for the Atmos Stack"
  type        = string
}

variable "stage" {
  description = "Name of stage"
  type        = string
}

variable "location" {
  description = "Azure region for deployment"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key to use for VM access."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the private SSH key for remote provisioner and SSH access."
  type        = string
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
}

variable "vnet_cidr" {
  description = "Azure VNet CIDR"
  type        = string
}

variable "subnet_cidr" {
  description = "Azure Subnet CIDR"
  type        = string
}

variable "vm_size" {
  description = "VM size for performance testing instances"
  type        = string
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 2
}

variable "admin_username" {
  description = "Admin username for the VMs"
  type        = string
  default     = "ubuntu"
}

variable "oauth_client_id" {
  description = "OAuth client ID for Tailscale"
  type        = string
  sensitive   = true
}

variable "oauth_client_secret" {
  description = "OAuth client secret for Tailscale"
  type        = string
  sensitive   = true
}

variable "enable_accelerated_networking" {
  description = "Enable accelerated networking for the VMs"
  type        = bool
  default     = true
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 30
}

variable "os_disk_type" {
  description = "Type of OS disk"
  type        = string
  default     = "StandardSSD_LRS"
}

variable "source_image_reference" {
  description = "Source image reference for the VMs"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
