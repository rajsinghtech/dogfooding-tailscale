output "Message" {
  description = "Instructions for configuring your environment after Terraform apply."
  value       = <<-EOT
Next Steps:
1. Configure your kubeconfig for direct APIserver access by running:
   az aks get-credentials --resource-group ${local.resource_group_name} --name ${local.cluster_name} --overwrite-existing

2. Test SSH to the VM's public IP:
   ssh -i ${local.ssh_private_key_path} ubuntu@${local.azure_vm_client_public_ip}

3. Configure your kubeconfig for Tailscale Operator APIserver proxy access by running:
   tailscale configure kubeconfig ${local.tenant}-${local.environment}-${local.stage}-operator

Happy deploying <3
EOT
}