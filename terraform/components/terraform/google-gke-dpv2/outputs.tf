output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
  sensitive   = true
}

output "gke_cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "The CA certificate of the GKE cluster"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
  sensitive   = true
}

output "project_id" {
  description = "The Google Cloud project ID"
  value       = local.project_id
  sensitive   = true
}

output "region" {
  description = "The Google Cloud region"
  value       = local.region
  sensitive   = true
}

output "oauth_client_id" {
  description = "OAuth client ID for Tailscale"
  value       = local.oauth_client_id
  sensitive   = true
}

output "oauth_client_secret" {
  description = "OAuth client secret for Tailscale"
  value       = local.oauth_client_secret
  sensitive   = true
}

output "sr_instance_hostname" {
  description = "Tailscale hostname for the subnet router"
  value       = local.sr_instance_hostname
  sensitive   = true
}

output "gke_service_range_cidr" {
  description = "CIDR range for GKE services"
  value       = var.gke_service_range_cidr
  sensitive   = true
}

output "sr_mig_public_ips" {
  description = "Public IPs of subnet router MIG instances"
  value       = local.enable_sr ? data.external.mig_ips[0].result.ips : null
  sensitive   = true
}

output "subnets" {
  description = "The subnet details from the VPC module"
  value       = module.vpc.subnets
  sensitive   = true
}

output "Message" {
  description = "Instructions for configuring your environment after Terraform apply"
  value = join("\n", compact([
    "Next Steps:",
    "",
    "1. Configure kubectl:",
    "   gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${local.region} --project ${local.project_id}",
    "",
    "2. SSH to subnet router:",
    local.enable_sr && length(split(",", data.external.mig_ips[0].result.ips)) > 0 ? join("\n", [
      for idx, ip in split(",", data.external.mig_ips[0].result.ips) :
      "   ssh ubuntu@${ip} # ${local.sr_instance_hostname}-${idx + 1}"
    ]) : "   N/A (subnet router not enabled)",
    "",
    "Happy deploying <3"
  ]))
}
