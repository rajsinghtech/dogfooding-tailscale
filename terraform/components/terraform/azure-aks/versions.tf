terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.22"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "tailscale" {
  oauth_client_id     = local.oauth_client_id
  oauth_client_secret = local.oauth_client_secret
}
