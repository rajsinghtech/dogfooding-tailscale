terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.13.7"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
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
  kubernetes {
    host                   = local.aks_cluster_host
    cluster_ca_certificate = local.aks_cluster_ca_certificate
    client_key             = local.aks_cluster_client_key
    client_certificate     = local.aks_cluster_client_certificate
  }
}