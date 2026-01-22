#
# Variables for all resources
#
variable "project_id" {
  description = "The Google Cloud project ID to deploy to"
  type        = string
}
variable "region" {
  description = "The Google Cloud region to deploy to"
  type        = string
}
variable "name" {
  description = "Name for all resources"
  type        = string
}

#
# Variables for network resources
#
variable "subnets" {
  description = "List of subnet configurations"
  type = list(object({
    subnet_name           = string
    subnet_ip             = string
    subnet_region         = string
    subnet_range_name     = optional(string)
    subnet_private_access = optional(bool, false)
    subnet_flow_logs      = optional(bool, false)
  }))
}

variable "secondary_ranges" {
  description = "Secondary ranges for GKE subnets"
  type        = map(list(object({ range_name = string, ip_cidr_range = string })))
  default     = {}
}

variable "create_router" {
  description = "Whether to create a Cloud Router"
  type        = bool
  default     = true
}

variable "router_name" {
  description = "Name for the Cloud Router"
  type        = string
  default     = null
}

variable "create_nat" {
  description = "Whether to create a Cloud NAT"
  type        = bool
  default     = true
}

variable "enable_endpoint_independent_mapping" {
  description = "Enable endpoint independent mapping for NAT"
  type        = bool
  default     = true
}
