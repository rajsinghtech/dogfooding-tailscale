data "azurerm_kubernetes_cluster" "credentials" {
  name                = local.cluster_name
  resource_group_name = local.resource_group_name
}

# Rewrite the per-cluster domain used by split-DNS across clusters. AKS reconciles
# the coredns ConfigMap itself; coredns-custom "*.override" keys are imported
# into its default server block.
resource "kubectl_manifest" "coredns" {
  wait      = true
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  tailscale-split-dns.override: |
    rewrite name substring ${local.environment}.svc.cluster.local svc.cluster.local answer auto
YAML
}

####################################################################
# TS Split-DNS setup for K8s service FQDN resolution from Azure VM #
####################################################################

data "kubernetes_service_v1" "kubedns" {
  metadata {
    name      = "kube-dns"
    namespace = "kube-system"
  }
}

resource "tailscale_dns_split_nameservers" "coredns_split_nameservers" {
  domain      = "${local.environment}.svc.cluster.local"
  nameservers = [data.kubernetes_service_v1.kubedns.spec[0].cluster_ip]
}

################################################################################
# Flux Operator + FluxInstance. Flux installs the Tailscale operator and every
# workload from var.flux_cluster_path.
################################################################################
module "flux_bootstrap" {
  source = "../modules/flux-bootstrap"

  cluster_path                  = var.flux_cluster_path
  git_url                       = var.flux_git_url
  git_ref                       = var.flux_git_ref
  sops_gpg_private_key          = file(var.sops_gpg_private_key_file)
  tailscale_oauth_client_id     = local.oauth_client_id
  tailscale_oauth_client_secret = local.oauth_client_secret

  depends_on = [kubectl_manifest.coredns]
}
