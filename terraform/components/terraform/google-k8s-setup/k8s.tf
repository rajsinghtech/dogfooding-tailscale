

# Rewrite the domain for unique ones for split-DNS across clusters
resource "kubectl_manifest" "coredns" {
  wait      = true
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
          }
        ready
        rewrite name substring ${local.environment}.svc.cluster.local svc.cluster.local answer auto
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
YAML
}

####################################################################
# TS Split-DNS setup for K8s service FQDN resolution from GCE VM   #
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
