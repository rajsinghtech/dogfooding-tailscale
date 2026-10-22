output "tailnet_id" {
  value = tailscale_tailnet.this.id
}

output "oauth_client_id" {
  value     = tailscale_tailnet.this.oauth_client_id
  sensitive = true
}

output "oauth_client_secret" {
  value     = tailscale_tailnet.this.oauth_client_secret
  sensitive = true
}

output "message" {
  description = "Created tailnet"
  value       = format("API-only tailnet %s (%s) created, DNS suffix %s.", tailscale_tailnet.this.display_name, tailscale_tailnet.this.id, tailscale_tailnet.this.dns_name)
}
