output "Message" {
  description = "Instructions for configuring your environment after Terraform apply."
  value       = <<-EOT
Next Steps:
1. Configure your kubeconfig for direct APIserver access by running:
   aws eks --region ${local.region} update-kubeconfig --name ${local.cluster_name} --alias ${local.cluster_name}

2. Configure your kubeconfig for Tailscale Operator APIserver proxy access by running:
   tailscale configure kubeconfig ${local.tenant}-${local.environment}-${local.stage}-operator

Happy deploying <3
EOT
}