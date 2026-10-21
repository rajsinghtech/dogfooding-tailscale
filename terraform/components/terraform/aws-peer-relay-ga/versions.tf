terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0, < 9.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.29.0, < 0.30.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.4.0, < 3.0.0"
    }
  }
}
