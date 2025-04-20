terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.13.7"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3.0"
    }
  }
} 