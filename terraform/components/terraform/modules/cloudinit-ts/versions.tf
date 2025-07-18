terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.21"
    }
  }
}