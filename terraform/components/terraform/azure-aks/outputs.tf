output "sr_instance_hostname" {
  value     = local.sr_instance_hostname
  sensitive = true
}

output "vnet_cidr" {
  value     = local.vnet_cidr
  sensitive = true
}

output "aks_service_ipv4_cidr" {
  value     = local.aks_service_ipv4_cidr
  sensitive = true
}

output "ssh_private_key_path" {
  value     = local.ssh_private_key_path
  sensitive = true
}

output "resource_group_name" {
  value     = azurerm_resource_group.main.name
  sensitive = true
}

output "aks_cluster_host" {
  value     = azurerm_kubernetes_cluster.main.kube_config[0].host
  sensitive = true
}

output "aks_cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "aks_cluster_name" {
  value     = azurerm_kubernetes_cluster.main.name
  sensitive = true
}

output "oauth_client_id" {
  value     = local.oauth_client_id
  sensitive = true
}

output "oauth_client_secret" {
  value     = local.oauth_client_secret
  sensitive = true
}

output "sr_vmss_name" {
  description = "Name of the subnet router VM Scale Set"
  value       = local.enable_sr ? azurerm_linux_virtual_machine_scale_set.sr[0].name : null
  sensitive   = true
}

output "sr_vmss_public_ips" {
  description = "Public IPs of subnet router VMSS instances"
  value       = local.enable_sr ? data.external.vmss_ips[0].result.ips : null
  sensitive   = true
}

output "Message" {
  description = "Instructions for configuring your environment after Terraform apply"
  value = join("\n", compact([
    "Next Steps:",
    "",
    "1. Configure kubectl:",
    "   az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name} --overwrite-existing",
    "",
    "2. SSH to subnet router:",
    local.enable_sr && length(split(",", data.external.vmss_ips[0].result.ips)) > 0 ? join("\n", [
      for idx, ip in split(",", data.external.vmss_ips[0].result.ips) :
      "   ssh -i ${local.ssh_private_key_path} ubuntu@${ip} # ${local.sr_instance_hostname}-${idx + 1}"
    ]) : "   N/A (subnet router not enabled)",
    "",
    "Happy deploying <3"
  ]))
}
