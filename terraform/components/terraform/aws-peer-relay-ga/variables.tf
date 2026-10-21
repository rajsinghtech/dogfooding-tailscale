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

variable "region" {
  description = "AWS region for the peer relay"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = null
}

variable "gcp_project_id" {
  description = "Google Cloud project for the client VMs"
  type        = string
}

variable "tailscale_api_key" {
  description = "Tailscale API key, or file:/path/to/key"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}

variable "relay_mode" {
  description = "none: no relay server (DERP baseline). public: relay on a public IP. ga: relay in a private subnet behind Global Accelerator"
  type        = string
  validation {
    condition     = contains(["none", "public", "ga"], var.relay_mode)
    error_message = "relay_mode must be one of \"none\", \"public\", \"ga\"."
  }
}

variable "relay_port" {
  description = "UDP port for the Tailscale peer relay"
  type        = number
  default     = 40000
  validation {
    condition     = var.relay_port >= 1024 && var.relay_port <= 65535
    error_message = "relay_port must be between 1024 and 65535."
  }
}

variable "vpc_cidr" {
  description = "AWS VPC CIDR for the relay"
  type        = string
}

variable "relay_instance_type" {
  description = "EC2 instance type for the peer relay"
  type        = string
  default     = "c6in.large"
}

variable "clients" {
  description = "GCP client VMs keyed by short name. Each gets its own VPC behind Cloud NAT and runs tailscaled with TS_DEBUG_NEVER_DIRECT_UDP, so traffic between clients goes over DERP or the peer relay"
  type = map(object({
    region      = string
    zone        = string
    subnet_cidr = string
  }))
}

variable "client_machine_type" {
  description = "GCE machine type for the clients"
  type        = string
  default     = "n2-standard-4"
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
