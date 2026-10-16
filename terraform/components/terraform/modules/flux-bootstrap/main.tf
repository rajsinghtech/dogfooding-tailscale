# Flux Operator owns the Flux installation. Everything else in the cluster,
# including the Tailscale operator, is reconciled by Flux from cluster_path.
resource "helm_release" "flux_operator" {
  name             = "flux-operator"
  repository       = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart            = "flux-operator"
  version          = var.flux_operator_version
  namespace        = "flux-system"
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
}

resource "kubernetes_secret_v1" "sops_gpg" {
  metadata {
    name      = "sops-gpg"
    namespace = helm_release.flux_operator.namespace
  }
  data = {
    "sops.asc" = var.sops_gpg_private_key
  }
}

# Flux also applies this Namespace (with prune disabled), so only create it here.
resource "kubernetes_namespace_v1" "tailscale" {
  metadata {
    name = "tailscale"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

# Mounted by the tailscale-operator HelmRelease (clusters/common/apps/tailscale/operator).
resource "kubernetes_secret_v1" "operator_oauth" {
  metadata {
    name      = "operator-oauth"
    namespace = kubernetes_namespace_v1.tailscale.metadata[0].name
  }
  data = {
    client_id     = var.tailscale_oauth_client_id
    client_secret = var.tailscale_oauth_client_secret
  }
}

resource "kubectl_manifest" "flux_instance" {
  yaml_body = templatefile("${path.module}/../../../../../clusters/common/bootstrap/flux-instance.yaml", {
    FLUX_VERSION = var.flux_version
    GIT_URL      = var.git_url
    GIT_REF      = var.git_ref
    CLUSTER_PATH = var.cluster_path
  })

  wait_for {
    condition {
      type   = "Ready"
      status = "True"
    }
  }

  timeouts {
    create = var.flux_ready_timeout
    update = var.flux_ready_timeout
  }

  depends_on = [
    helm_release.flux_operator,
    kubernetes_secret_v1.sops_gpg,
    kubernetes_secret_v1.operator_oauth,
  ]
}
