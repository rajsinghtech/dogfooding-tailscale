terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.0, < 6.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.29.0, < 0.30.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0, < 4.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.4.0, < 3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.4.0, < 3.0.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "tailscale" {
  oauth_client_id     = local.oauth_client_id
  oauth_client_secret = local.oauth_client_secret
}
