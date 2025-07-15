variable "project_id" {
  description = "The Google Cloud project ID to deploy to"
  type        = string
}

variable "name" {
  description = "Name for all resources"
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