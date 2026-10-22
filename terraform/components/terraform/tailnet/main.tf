resource "tailscale_tailnet" "this" {
  display_name = format("%s-%s-%s", var.tenant, var.environment, var.stage)
}
