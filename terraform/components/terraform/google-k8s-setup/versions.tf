terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.47.0"
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

data "google_client_config" "default" {}

provider "google" {
  project = local.project_id
  region  = local.region
}

provider "tailscale" {
  oauth_client_id     = local.oauth_client_id
  oauth_client_secret = local.oauth_client_secret
}

provider "kubernetes" {
  host                   = "https://${local.gke_cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = local.gke_cluster_ca_certificate

  ignore_annotations = [
    "^autopilot\\.gke\\.io\\/.*",
    "^cloud\\.google\\.com\\/.*"
  ]
}

provider "kubectl" {
  host                   = "https://${local.gke_cluster_endpoint}"
  cluster_ca_certificate = local.gke_cluster_ca_certificate
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = "https://${local.gke_cluster_endpoint}"
    cluster_ca_certificate = local.gke_cluster_ca_certificate
    token                  = data.google_client_config.default.access_token
  }
}
