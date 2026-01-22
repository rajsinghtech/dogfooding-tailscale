output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.primary.id
}

output "cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The CA certificate of the GKE cluster"
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "subnets" {
  description = "The subnet details from the VPC module"
  value       = module.vpc.subnets
}

output "gcloud_get_credentials" {
  description = "gcloud command to configure kubectl with the GKE cluster credentials"
  value       = <<-EOT
    # Run this command to configure kubectl to connect to your GKE cluster:
    gcloud container clusters get-credentials ${google_container_cluster.primary.name} \
      --region ${google_container_cluster.primary.location} \
      --project ${google_container_cluster.primary.project}
  EOT
}

output "pvt_vm_test_private_ip" {
  description = "Private IP address of the private test VM"
  value       = var.enable_sr ? google_compute_instance.pvt_vm_test[0].network_interface[0].network_ip : null
}