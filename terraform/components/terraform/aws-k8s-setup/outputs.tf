output "Message" {
  description = "Instructions for configuring your environment after Terraform apply."
  value = <<-EOT
Next Steps:
1. Configure your kubeconfig for direct APIserver access by running:
   aws eks --region ${local.region} update-kubeconfig --name ${local.name} --alias ${local.name}

2. Configure your kubeconfig for Tailscale Operator APIserver proxy access by running:
   tailscale configure kubeconfig tailscale-operator-${local.environment}-${local.stage}

Happy deploying <3
EOT
}