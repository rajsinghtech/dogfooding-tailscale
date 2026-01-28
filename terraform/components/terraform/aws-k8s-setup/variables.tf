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

variable "flux_repo_url" {
  description = "Flux Git repository URL"
  type        = string
  default     = "https://github.com/rajsinghtech/dogfooding-tailscale"
}

variable "flux_cluster_name" {
  description = "Cluster name for Flux path (e.g., cluster2)"
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

