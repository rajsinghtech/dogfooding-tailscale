variable "name" {
  description = "Name of cluster"
  type        = string
}

variable "cluster_endpoint_public_access" {
  description = <<-EOF
  EKS cluster APIserver public endpoint access. 
  Don't set cluster_endpoint_private_access to true if you set this to true
  EOF
  type        = bool
}

variable "cluster_endpoint_private_access" {
  description = <<-EOF
  EKS cluster APIserver private endpoint access. 
  Don't set cluster_endpoint_public_access to true if you set this to true
  EOF
  type        = bool
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

variable "region" {
  description = "AWS Region of cluster"
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
}

variable "sr_ec2_instance_type" {
  description = "EC2 SR instance type"
  type        = string
}

variable "sr_ec2_asg_min_size" {
  description = "Minimum number of EC2 instances in the autoscaling group"
  type        = number
}

variable "sr_ec2_asg_max_size" {
  description = "Maximum number of EC2 instances in the autoscaling group"
  type        = number
}

variable "sr_ec2_asg_desired_size" {
  description = "Desired number of EC2 instances in the autoscaling group"
  type        = number
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
  description = "Tailscale Machine hostname of the EC2 instance"
  type        = string
}

variable "ec2_hostname" {
  description = "Tailscale Machine hostname of the EC2 instance"
  type        = string
}

variable "advertise_routes" {
  description = "List of CIDR blocks to advertise via Tailscale in addition to the EKS private subnets"
  type        = list(string)
  default     = []
}
