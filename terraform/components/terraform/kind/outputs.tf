output "endpoint" {
  value = kind_cluster.this.endpoint
}

output "client_certificate" {
  value     = kind_cluster.this.client_certificate
  sensitive = true
}

output "client_key" {
  value     = kind_cluster.this.client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = kind_cluster.this.cluster_ca_certificate
  sensitive = true
}

output "oauth_client_id" {
  value     = tailscale_oauth_client.operator.id
  sensitive = true
}

output "oauth_client_secret" {
  value     = tailscale_oauth_client.operator.key
  sensitive = true
}

output "message" {
  description = "How to reach the cluster"
  value       = format("Kind cluster %s is up.\nkubectl --context %s get pods -A", kind_cluster.this.name, kind_cluster.this.context_name)
}
