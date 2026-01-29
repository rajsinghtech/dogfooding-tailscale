terraform {
  required_version = ">= 1.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.13.7"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.6"
    }
  }
}
