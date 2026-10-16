output "cluster_ip" {
  description = "ClusterIP to use as the Tailscale split-DNS nameserver"
  value       = kubernetes_service_v1.this.spec[0].cluster_ip
}
