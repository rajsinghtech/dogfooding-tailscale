# Use tfstate values from phase-1 for the providers defined in locals.tf
provider "tailscale" {
  oauth_client_id     = local.oauth_client_id
  oauth_client_secret = local.oauth_client_secret
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
  load_config_file       = false
}

provider "helm" {
  kubernetes = {
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
# Flux CD Operator Setup
################################################################################
resource "helm_release" "flux" {
  name             = "flux"
  repository       = "oci://ghcr.io/fluxcd-community/charts"
  chart            = "flux2"
  version          = "2.14.1"
  namespace        = "flux-system"
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
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
        hostname = "${local.tenant}-${local.environment}-${local.stage}-operator"
        image = {
          tag = var.tailscale_operator_image_tag
        }
      }
      proxyConfig = {
        image = {
          tag = var.tailscale_proxy_image_tag
        }
      }
    })
  ]
  depends_on = [
    kubectl_manifest.coredns
  ]
}

################################################################################
# AWS EBS CSI Driver Setup
################################################################################
resource "helm_release" "ebs_csi_driver" {

  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.30.0"

  values = [
    yamlencode({
      controller = {
        serviceAccount = {
          create = true
          name   = "ebs-csi-controller-sa"
          annotations = {
            "eks.amazonaws.com/role-arn" = local.eks_ebs_csi_iam_role_arn
          }
        }
      }
    })
  ]
}

################################################################################
# AWS Load Balancer Controller Setup
################################################################################
resource "helm_release" "aws_lb_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  version          = "1.7.1"
  create_namespace = false

  values = [
    yamlencode({
      clusterName = local.cluster_name
      region      = local.region
      vpcId       = local.vpc_id
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = local.aws_lb_controller_iam_role_arn
        }
      }
    })
  ]
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
