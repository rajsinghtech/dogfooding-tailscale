variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
  default     = "tailscale-sandbox"
}

variable "region" {
  description = "The region for the GKE cluster"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The zone for the GKE cluster"
  type        = string
  default     = "us-central1-a"
}

variable "authorized_networks" {
  description = "Map of CIDR blocks and their display names for master authorized networks"
  type        = map(string)
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "gke-autopilot-cluster"
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
