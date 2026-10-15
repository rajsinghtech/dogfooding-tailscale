terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.4.0, < 3.0.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.29.0, < 0.30.0"
    }
  }
}
