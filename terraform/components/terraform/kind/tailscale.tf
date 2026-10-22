resource "tailscale_tailnet_settings" "this" {
  https_enabled = true
}

resource "tailscale_acl" "this" {
  overwrite_existing_content = true
  acl = jsonencode({
    tagOwners = {
      "tag:k8s-operator" = []
      "tag:k8s"          = ["tag:k8s-operator"]
    }
    autoApprovers = {
      services = {
        "tag:k8s" = ["tag:k8s"]
      }
    }
    grants = [
      {
        src = ["*"]
        dst = ["*"]
        ip  = ["*"]
      }
    ]
  })
}

resource "tailscale_oauth_client" "operator" {
  description = "k8s operator"
  scopes      = ["auth_keys", "devices:core", "services"]
  tags        = ["tag:k8s-operator"]

  depends_on = [tailscale_acl.this]
}
