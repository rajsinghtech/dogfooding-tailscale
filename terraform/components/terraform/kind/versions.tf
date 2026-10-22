terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = ">= 0.13.0, < 0.14.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.29.0, < 0.30.0"
    }
  }
}

provider "tailscale" {
  oauth_client_id     = local.oauth_client_id
  oauth_client_secret = local.oauth_client_secret
  tailnet             = local.tailnet_id
}
