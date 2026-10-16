variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

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

variable "cluster_name" {
  description = "Cluster identifier (e.g., cluster1, cluster2)"
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
  default     = {}
}

variable "vnet_cidr" {
  description = "Azure VNet CIDR"
  type        = string
}

variable "aks_service_ipv4_cidr" {
  description = "Kubernetes Service CIDR"
  type        = string
}

variable "cluster_vm_size" {
  description = "VM size for AKS node pool"
  type        = string
}

variable "vm_size" {
  description = "VM size for Tailscale VM"
  type        = string
}

variable "aks_version" {
  description = "Kubernetes version for this cluster"
  type        = string
}

variable "node_count" {
  description = "Number of cluster nodes"
  type        = string
}

variable "cluster_outbound_type" {
  description = <<-EOF
  Outbound type for the cluster: Choose between 'userAssignedNATGateway' 
  to force hard NAT or 'loadBalancer' to get easy NAT.
  EOF
  type        = string
}

variable "oauth_client_id" {
  type        = string
  sensitive   = true
  description = <<-EOF
  The OAuth application's ID when using OAuth client credentials.
  Can be set via the TAILSCALE_OAUTH_CLIENT_ID environment variable.
  Both 'oauth_client_id' and 'oauth_client_secret' must be set.
  EOF
}

variable "oauth_client_secret" {
  type        = string
  sensitive   = true
  description = <<-EOF
  (Sensitive) The OAuth application's secret when using OAuth client credentials.
  Can be set via the TAILSCALE_OAUTH_CLIENT_SECRET environment variable.
  Both 'oauth_client_id' and 'oauth_client_secret' must be set.
  EOF
}

variable "sr_instance_hostname" {
  description = "Tailscale Machine hostname"
  type        = string
}

variable "advertise_routes" {
  description = "List of CIDR blocks to advertise via Tailscale in addition to the AKS private subnets"
  type        = list(string)
  default     = []
}

variable "tailscale_track" {
  description = "Version of the Tailscale client to install"
  type        = string
  default     = "stable"
  validation {
    condition     = contains(["stable", "unstable"], var.tailscale_track)
    error_message = "Allowed values for tailscale_track are \"stable\", \"unstable\""
  }
}

variable "tailscale_peer_relay_port" {
  description = "UDP port for the Tailscale peer relay on the subnet routers (null disables the peer relay)"
  type        = number
  default     = null
  validation {
    condition = (
      var.tailscale_peer_relay_port == null ||
      (var.tailscale_peer_relay_port >= 1024 && var.tailscale_peer_relay_port <= 65535)
    )
    error_message = "tailscale_peer_relay_port must be between 1024 and 65535 if set."
  }
}

variable "enable_sr" {
  description = "Enable subnet router VM Scale Set deployment"
  type        = bool
  default     = true
}

variable "sr_vmss_desired_size" {
  description = "Desired number of VMs in the subnet router scale set"
  type        = number
  default     = 1
}

variable "sr_accept_routes" {
  description = "Whether the subnet router should accept routes from other devices"
  type        = bool
  default     = false
}

variable "sr_enable_ssh" {
  description = "Whether to enable SSH on the subnet router"
  type        = bool
  default     = true
}

variable "sr_ephemeral" {
  description = "Whether the subnet router should be ephemeral"
  type        = bool
  default     = true
}

variable "sr_reusable" {
  description = "Whether the subnet router auth key should be reusable"
  type        = bool
  default     = true
}

variable "sr_primary_tag" {
  description = "Primary tag for the subnet router"
  type        = string
  default     = "subnet-router"
}

variable "private_cluster_enabled" {
  description = "Expose the AKS API server only on a private endpoint (reached over the tailnet through the subnet router)"
  type        = bool
  default     = true
}

variable "api_server_authorized_ip_ranges" {
  description = "Public CIDRs allowed to reach the API server when private_cluster_enabled is false"
  type        = list(string)
  default     = []
}
