terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0, < 9.0"
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
  kubernetes = {
    host                   = "https://${local.gke_cluster_endpoint}"
    cluster_ca_certificate = local.gke_cluster_ca_certificate
    token                  = data.google_client_config.default.access_token
  }
}
