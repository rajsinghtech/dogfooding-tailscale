variable "cluster_path" {
  description = "Path in the Git repository that Flux syncs for this cluster, e.g. clusters/cluster2/flux"
  type        = string
}

variable "git_url" {
  description = "Git repository Flux syncs from"
  type        = string
  default     = "https://github.com/rajsinghtech/dogfooding-tailscale"
}

variable "git_ref" {
  description = "Git reference Flux syncs, e.g. refs/heads/main"
  type        = string
  default     = "refs/heads/main"
}

# Defaults must match clusters/common/bootstrap/versions.env (checked in CI).
variable "flux_version" {
  description = "Flux distribution version installed by the FluxInstance"
  type        = string
  # renovate: datasource=github-releases depName=fluxcd/flux2
  default = "2.9.6"
}

variable "flux_operator_version" {
  description = "Flux Operator Helm chart version"
  type        = string
  # renovate: datasource=docker depName=ghcr.io/controlplaneio-fluxcd/charts/flux-operator
  default = "0.61.0"
}

variable "sops_gpg_private_key" {
  description = "ASCII-armored private PGP key that decrypts clusters/*/flux/vars/*.sops.yaml"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID for the Kubernetes operator"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret for the Kubernetes operator"
  type        = string
  sensitive   = true
}

variable "flux_ready_timeout" {
  description = "How long to wait for the FluxInstance to become Ready"
  type        = string
  default     = "10m"
}
