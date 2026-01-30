terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.47.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.47.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.22"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
  required_version = ">= 1.0.0"
}
