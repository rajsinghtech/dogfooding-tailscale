terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.29.0, < 0.30.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.9.0, < 3.0.0"
    }
  }
}
