# Use tfstate values from phase-1 for the providers defined in locals.tf
provider "tailscale" {
  oauth_client_id        = local.oauth_client_id
  oauth_client_secret    = local.oauth_client_secret
}

provider "kubernetes" {
  host                   = local.eks_cluster_endpoint
  cluster_ca_certificate = local.eks_cluster_ca_certificate
  token                  = local.eks_cluster_auth_token
}

provider "kubectl" {
  host                   = local.eks_cluster_endpoint
  cluster_ca_certificate = local.eks_cluster_ca_certificate
  token                  = local.eks_cluster_auth_token
}

provider "helm" {
  kubernetes {
    host                   = local.eks_cluster_endpoint
    cluster_ca_certificate = local.eks_cluster_ca_certificate
    token                  = local.eks_cluster_auth_token
  }
}

# Get EKS cluster auth token for use
data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

################################################################################
# Tailscale Kubernetes Operator Setup
################################################################################
resource "helm_release" "tailscale_operator" {
  name             = "tailscale-operator-${local.environment}-${local.stage}"
  chart            = "tailscale-operator"
  repository       = "https://pkgs.tailscale.com/helmcharts"
  namespace        = "tailscale"
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  values = [
    yamlencode({
      oauth = {
        clientId     = local.oauth_client_id
        clientSecret = local.oauth_client_secret
      }
      apiServerProxyConfig = {
        mode = "true"
      }
      operatorConfig = {
        hostname = "tailscale-operator-${local.environment}-${local.stage}"
      }
    })
  ]
}

######################################################################
# Install ArgoCD via Helm                                            #
######################################################################

resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.8.26"
  namespace        = "argocd"
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  values           = [file("${path.module}/../files/argocd-values.yaml")]
}

######################################################################
# Apply manifests and CRs                                            #
######################################################################
data "kubectl_path_documents" "docs" {
  pattern = "manifests/*.yaml"
}

# Deploy all manifests into the cluster 
resource "kubectl_manifest" "app_manifests" {
  for_each  = data.kubectl_path_documents.docs.manifests
  yaml_body = each.value
}

# Create a ProxyClass to standardize configs applied to operator resources
resource "kubectl_manifest" "proxyclass" {
    wait      = true
    yaml_body = <<YAML
apiVersion: tailscale.com/v1alpha1
kind: ProxyClass
metadata:
  name: ${local.stage}
spec:
  statefulSet:
    pod:
      labels:
        tenant: ${local.tenant}
        environment: ${local.environment}
        stage: ${local.stage}
      nodeSelector:
        beta.kubernetes.io/os: "linux"
YAML
    depends_on = [
    helm_release.tailscale_operator
    ]
}

# Create the Connector CR for subnet router w/the proxy class
resource "kubectl_manifest" "connector" {
    wait      = true
    yaml_body = <<YAML
apiVersion: tailscale.com/v1alpha1
kind: Connector
metadata:
  name: ${local.name}-cluster-cidrs
spec:
  proxyClass: ${local.stage}
  hostname: ${local.name}-cluster-cidrs
  subnetRouter:
    advertiseRoutes:
      - "${local.vpc_cidr}"
      - "${local.cluster_service_ipv4_cidr}"
  tags:
    - "tag:k8s-operator"
YAML
    depends_on = [
    helm_release.tailscale_operator
    ]
}

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
###################################################################
# TS Split-DNS setup for K8s service FQDN resolution from tailnet #
###################################################################

data "kubernetes_service" "kubedns" {
  metadata {
    name      = "kube-dns"
    namespace = "kube-system"
  }
}

resource "tailscale_dns_split_nameservers" "coredns_split_nameservers" {
  domain      = "${local.environment}.svc.cluster.local"
  nameservers = [data.kubernetes_service.kubedns.spec[0].cluster_ip]
}
