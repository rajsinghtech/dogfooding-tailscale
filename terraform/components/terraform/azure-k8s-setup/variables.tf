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

variable "proxy_replicas" {
  description = "Number of replicas for Tailscale ProxyGroup pods"
  type        = string
}

variable "tailscale_operator_image_tag" {
  description = "Image tag for the Tailscale operator (e.g., 'stable', 'unstable', or a specific version)"
  type        = string
  default     = "stable"
}

variable "tailscale_proxy_image_tag" {
  description = "Image tag for the Tailscale proxy (e.g., 'stable', 'unstable', or a specific version)"
  type        = string
  default     = "stable"
}