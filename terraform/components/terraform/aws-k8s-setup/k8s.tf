# Use tfstate values from phase-1 for the providers defined in locals.tf
provider "aws" {
  region = local.region
}

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
# AWS EBS CSI Driver Setup
################################################################################
resource "helm_release" "ebs_csi_driver" {

  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.67.0"

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
  version          = "3.6.0"
  create_namespace = false
  # The chart emits IngressClassParams and IngressClass as one v1 List so Helm
  # applies them in order. A List has no OpenAPI v3 schema, so the Helm client
  # validates it against protobuf /openapi/v2, and the EKS 1.36 API server
  # answers that with an empty 503 (JSON /openapi/v2 and each object on its own
  # both succeed). Skip the client-side check; the API server still admits the
  # objects.
  disable_openapi_validation = true

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

# Default StorageClass backed by the EBS CSI driver (Prometheus PVCs use it).
resource "kubectl_manifest" "storageclass_gp3" {
  yaml_body = <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
YAML

  depends_on = [helm_release.ebs_csi_driver]
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

  depends_on = [helm_release.aws_lb_controller, kubectl_manifest.storageclass_gp3, kubectl_manifest.coredns]
}
