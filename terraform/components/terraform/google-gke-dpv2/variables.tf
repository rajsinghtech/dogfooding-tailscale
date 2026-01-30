variable "project_id" {
  description = "The Google Cloud project ID to deploy to"
  type        = string
}

variable "cluster_name" {
  description = "Cluster identifier (e.g., cluster4)"
  type        = string
}

variable "region" {
  description = "The Google Cloud region to deploy to"
  type        = string
}

variable "zone" {
  description = "The Google Cloud zone to deploy to"
  type        = string
}

variable "enable_endpoint_independent_mapping" {
  description = "Enable endpoint independent mapping aka easy NAT. This is required for some applications that expect consistent NAT behavior."
  type        = bool
  default     = true
}

variable "machine_type" {
  description = "The machine type to use for GKE nodes"
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the GKE node pool"
  type        = number
}

variable "ssh_public_keys" {
  description = "List of SSH public keys in format 'username:publickey' for VM access"
  type        = list(string)
}

variable "service_account" {
  description = "Service account email for GKE nodes"
  type        = string
  default     = ""
}

variable "authorized_networks" {
  description = "List of CIDR blocks that can access the Kubernetes API"
  type = list(object({
    name = string
    cidr = string
  }))
}

variable "enable_sr" {
  description = "Enable subnet router functionality"
  type        = bool
}

variable "enable_private_endpoint" {
  description = "When true, the GKE control plane is only accessible via private IP (requires subnet router or VPN for access)"
  type        = bool
  default     = false
}

variable "sr_instance_hostname" {
  description = "Tailscale Machine hostname for the subnet router"
  type        = string
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
  default     = false
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

variable "advertise_routes" {
  description = "Additional CIDR blocks to advertise to Tailscale (VPC subnets are included automatically)"
  type        = list(string)
  default     = []
}

variable "vpc_subnet_cidr" {
  description = "CIDR range for the main VPC subnet"
  type        = string
}

variable "gke_subnet_cidr" {
  description = "CIDR range for the GKE subnet"
  type        = string
}

variable "gke_pod_range_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
}

variable "gke_service_range_cidr" {
  description = "CIDR range for GKE services"
  type        = string
}

variable "gke_master_cidr" {
  description = "CIDR range for GKE control plane nodes (must be /28 range)"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/28$", var.gke_master_cidr))
    error_message = "The gke_master_cidr must be a valid /28 CIDR block (e.g., 172.16.0.0/28), not overlapping with any other cidrs defined."
  }
}

variable "tenant" {
  description = "The tenant name for the cluster"
  type        = string
  default     = "sales"
}

variable "environment" {
  description = "The environment name for the cluster"
  type        = string
  default     = "sandbox"
}

variable "stage" {
  description = "The stage name for the cluster"
  type        = string
  default     = "test"
}

variable "oauth_client_id" {
  description = "The OAuth client ID for the cluster"
  type        = string
}

variable "oauth_client_secret" {
  description = "The OAuth client secret for the cluster"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}

variable "kubelet_config" {
  type = object({
    cpu_manager_policy   = optional(string)
    cpu_cfs_quota        = optional(bool)
    cpu_cfs_quota_period = optional(string)
    pod_pids_limit       = optional(number)
  })
  default = {}
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

variable "tailscale_relay_server_port" {
  description = "Port for the Tailscale peer relay server (only available in unstable track)"
  type        = number
  default     = null
  validation {
    condition = (
      var.tailscale_relay_server_port == null ||
      (var.tailscale_relay_server_port >= 1024 && var.tailscale_relay_server_port <= 65535)
    )
    error_message = "tailscale_relay_server_port must be between 1024 and 65535 if set."
  }
}

variable "sr_mig_desired_size" {
  description = "Desired number of subnet router instances in the MIG"
  type        = number
  default     = 1
}

variable "kubernetes_version" {
  description = "Kubernetes version for the GKE cluster (e.g., 1.31)"
  type        = string
}