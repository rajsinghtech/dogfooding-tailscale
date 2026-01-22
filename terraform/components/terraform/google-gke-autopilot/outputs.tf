output "kubeconfig_command" {
  description = "Command to get kubeconfig for the GKE cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region}"
}

output "cluster_endpoint" {
  description = "The endpoint URL of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_region" {
  description = "The region where the GKE cluster is deployed"
  value       = var.region
}
