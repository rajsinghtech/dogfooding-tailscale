terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.0, < 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0, < 4.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.4.0, < 3.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.29.0, < 0.30.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0, < 4.0"
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

provider "kubernetes" {
  host                   = local.aks_cluster_host
  cluster_ca_certificate = local.aks_cluster_ca_certificate
  client_key             = local.aks_cluster_client_key
  client_certificate     = local.aks_cluster_client_certificate
}

provider "kubectl" {
  host                   = local.aks_cluster_host
  cluster_ca_certificate = local.aks_cluster_ca_certificate
  client_key             = local.aks_cluster_client_key
  client_certificate     = local.aks_cluster_client_certificate
}

provider "helm" {
  kubernetes = {
    host                   = local.aks_cluster_host
    cluster_ca_certificate = local.aks_cluster_ca_certificate
    client_key             = local.aks_cluster_client_key
    client_certificate     = local.aks_cluster_client_certificate
  }
}
