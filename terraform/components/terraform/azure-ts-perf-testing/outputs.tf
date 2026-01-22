output "message" {
  description = "Connection information"
  value       = format("SSH Instructions:\n%s", join("\n", [for idx, ip in azurerm_public_ip.vm : "ssh -i ${var.ssh_private_key_path} ${var.admin_username}@${ip.ip_address}"]))
}
