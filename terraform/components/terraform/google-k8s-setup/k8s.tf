

####################################################################
# TS Split-DNS setup for K8s service FQDN resolution from GCE VM   #
####################################################################

data "kubernetes_service_v1" "kubedns" {
  metadata {
    name      = "kube-dns"
    namespace = "kube-system"
  }
}

# GKE runs kube-dns, which cannot rewrite names, so a dedicated CoreDNS answers
# the tailnet's split-DNS queries and forwards to kube-dns. Its ClusterIP is
# reachable through the Connector, which advertises the service range.
module "split_dns" {
  source = "../modules/split-dns-coredns"

  environment = local.environment
  upstream    = data.kubernetes_service_v1.kubedns.spec[0].cluster_ip
}

resource "tailscale_dns_split_nameservers" "coredns_split_nameservers" {
  domain      = "${local.environment}.svc.cluster.local"
  nameservers = [module.split_dns.cluster_ip]
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

  depends_on = [module.split_dns]
}
