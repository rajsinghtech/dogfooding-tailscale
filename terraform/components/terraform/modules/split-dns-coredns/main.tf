# A CoreDNS that answers tailnet split-DNS queries for <environment>.svc.cluster.local
# on clusters whose own DNS cannot rewrite names (GKE runs kube-dns).
locals {
  name   = "tailscale-split-dns"
  labels = { "app.kubernetes.io/name" = local.name }
}

resource "kubernetes_config_map_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }
  data = {
    Corefile = templatefile("${path.module}/Corefile.tftpl", {
      environment = var.environment
      upstream    = var.upstream
    })
  }
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = var.replicas
    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
        annotations = {
          "checksum/config" = sha256(kubernetes_config_map_v1.this.data.Corefile)
        }
      }

      spec {
        container {
          name  = "coredns"
          image = var.image
          args  = ["-conf", "/etc/coredns/Corefile"]

          port {
            name           = "dns"
            container_port = 53
            protocol       = "UDP"
          }
          port {
            name           = "dns-tcp"
            container_port = 53
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              memory = "128Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              add  = ["NET_BIND_SERVICE"]
              drop = ["ALL"]
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
          }
          readiness_probe {
            http_get {
              path = "/ready"
              port = 8181
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/coredns"
            read_only  = true
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.this.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.labels

    port {
      name        = "dns"
      port        = 53
      target_port = 53
      protocol    = "UDP"
    }
    port {
      name        = "dns-tcp"
      port        = 53
      target_port = 53
      protocol    = "TCP"
    }
  }
}
