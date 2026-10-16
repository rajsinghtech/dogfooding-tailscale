# Applies the same flux-bootstrap module as the *-k8s-setup roots, against the
# KWOK cluster in var.kubeconfig. Used by test/kwok/run.sh.
terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  backend "local" {}

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0, < 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0, < 4.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.4.0, < 3.0"
    }
  }
}

variable "kubeconfig" {
  type = string
}

variable "cluster_path" {
  type = string
}

variable "git_url" {
  type = string
}

variable "sops_gpg_private_key_file" {
  type = string
}

provider "kubernetes" {
  config_path = var.kubeconfig
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig
  }
}

provider "kubectl" {
  config_path      = var.kubeconfig
  load_config_file = true
}

module "flux_bootstrap" {
  source = "../../../terraform/components/terraform/modules/flux-bootstrap"

  cluster_path                  = var.cluster_path
  git_url                       = var.git_url
  sops_gpg_private_key          = file(var.sops_gpg_private_key_file)
  tailscale_oauth_client_id     = "kwok-client-id"
  tailscale_oauth_client_secret = "kwok-client-secret"
}

# Also exercise the GKE split-DNS CoreDNS manifests against a real API server.
module "split_dns" {
  source = "../../../terraform/components/terraform/modules/split-dns-coredns"

  environment = "kwok"
  upstream    = "10.96.0.10"
}
