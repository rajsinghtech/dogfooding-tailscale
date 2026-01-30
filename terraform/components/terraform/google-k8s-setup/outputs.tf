output "Message" {
  description = "Instructions for configuring your environment after Terraform apply."
  value       = <<-EOT
Next Steps:
1. Configure your kubeconfig for direct APIserver access by running:
   gcloud container clusters get-credentials ${local.cluster_name} --region ${local.region} --project ${local.project_id}

2. Configure your kubeconfig for Tailscale Operator APIserver proxy access by running:
   tailscale configure kubeconfig ${local.tenant}-${local.environment}-${local.stage}-operator

Happy deploying <3
EOT
}
