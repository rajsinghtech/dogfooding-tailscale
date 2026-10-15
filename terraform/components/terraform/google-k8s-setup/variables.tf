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
  description = "The Google Cloud region"
  type        = string
}

variable "flux_cluster_path" {
  description = "Path in the Git repository that Flux syncs for this cluster, e.g. clusters/cluster2/flux"
  type        = string
}

variable "flux_git_url" {
  description = "Git repository Flux syncs from"
  type        = string
  default     = "https://github.com/rajsinghtech/dogfooding-tailscale"
}

variable "flux_git_ref" {
  description = "Git reference Flux syncs, e.g. refs/heads/main"
  type        = string
  default     = "refs/heads/main"
}

variable "sops_gpg_private_key_file" {
  description = "Path to the ASCII-armored private PGP key for clusters/.sops.yaml (read at apply time, never commit it)"
  type        = string
}
