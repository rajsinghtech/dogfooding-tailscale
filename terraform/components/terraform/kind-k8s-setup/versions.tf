terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0, < 4.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.4.0, < 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0, < 4.0"
    }
  }
}

provider "kubernetes" {
  host                   = local.endpoint
  client_certificate     = local.client_certificate
  client_key             = local.client_key
  cluster_ca_certificate = local.cluster_ca_certificate
}

provider "kubectl" {
  host                   = local.endpoint
  client_certificate     = local.client_certificate
  client_key             = local.client_key
  cluster_ca_certificate = local.cluster_ca_certificate
  load_config_file       = false
}

provider "helm" {
  kubernetes = {
    host                   = local.endpoint
    client_certificate     = local.client_certificate
    client_key             = local.client_key
    cluster_ca_certificate = local.cluster_ca_certificate
  }
}
