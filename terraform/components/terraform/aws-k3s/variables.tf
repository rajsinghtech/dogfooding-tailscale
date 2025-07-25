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

variable "name" {
  description = "Name of the K3s cluster"
  type        = string
}

variable "region" {
  description = "AWS Region for the K3s VM"
  type        = string
}

variable "ssh_keyname" {
  description = "AWS SSH Keypair Name"
  type        = string
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

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "AWS VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the K3s node"
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
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

variable "instance_hostname" {
  description = "Tailscale Machine hostname of the EC2 instance"
  type        = string
}

variable "advertise_routes" {
  description = "List of CIDR blocks to advertise via Tailscale"
  type        = list(string)
  default     = []
}

variable "tailscale_tags" {
  description = "List of Tailscale tags to apply to the instance"
  type        = list(string)
  default     = ["tag:k3s"]
} 