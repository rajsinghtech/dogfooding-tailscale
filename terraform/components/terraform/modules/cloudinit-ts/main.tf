locals {

  primary_tag              = var.primary_tag
  prefixed_primary_tag     = "tag:${local.primary_tag}"
  prefixed_additional_tags = [for tag in var.additional_tags : "tag:${tag}"]
  
  tailscale_tags = concat([local.prefixed_primary_tag], local.prefixed_additional_tags)

  # Validate that relay_server_port is only set when track is "unstable"
  relay_server_validation = var.relay_server_port != null && var.track != "unstable" ? tobool("ERROR: The peer relay feature is only available in the unstable track. Please set track = \"unstable\" to use relay_server_port.") : true

}

data "cloudinit_config" "main" {
  depends_on    = [tailscale_tailnet_key.default]
  gzip          = var.gzip
  base64_encode = var.base64_encode

  part {
    filename     = "ip_forwarding.sh"
    content_type = "text/x-shellscript"
    content      = file("${path.module}/files/ip_forwarding.sh")
  }

  part {
    filename     = "udp_offloads.sh"
    content_type = "text/x-shellscript"
    content      = file("${path.module}/files/udp_offloads.sh")
  }

  part {
    filename     = "install_tailscale.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/install_tailscale.sh.tmpl", {
      TRACK       = var.track
      MAX_RETRIES = var.max_retries
      RETRY_DELAY = var.retry_delay
    })
  }

  part {
    filename     = "setup_tailscale.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/setup_tailscale.sh.tmpl", {
      ADVERTISE_ROUTES           = join(",", var.advertise_routes)
      ADVERTISE_TAGS             = join(",", local.tailscale_tags)
      ACCEPT_DNS                 = var.accept_dns
      ACCEPT_ROUTES              = var.accept_routes
      ADVERTISE_CONNECTOR        = var.advertise_connector
      ADVERTISE_EXIT_NODE        = var.advertise_exit_node
      HOSTNAME                   = var.hostname
      TAILSCALE_SSH              = var.enable_ssh
      AUTH_KEY                   = tailscale_tailnet_key.default.key
      EXIT_NODE                  = var.exit_node
      EXIT_NODE_ALLOW_LAN_ACCESS = var.exit_node_allow_lan_access
      FORCE_REAUTH               = var.force_reauth
      JSON                       = var.json
      LOGIN_SERVER               = var.login_server
      OPERATOR                   = var.operator
      RESET                      = var.reset
      SHIELDS_UP                 = var.shields_up
      TIMEOUT                    = var.timeout
      SNAT_SUBNET_ROUTES         = var.snat_subnet_routes
      NETFILTER_MODE             = var.netfilter_mode
      STATEFUL_FILTERING         = var.stateful_filtering
      MAX_RETRIES                = var.max_retries
      RETRY_DELAY                = var.retry_delay
      TRACK                      = var.track
      RELAY_SERVER_PORT          = var.relay_server_port != null ? var.relay_server_port : ""
    })
  }

  dynamic "part" {
    for_each = var.additional_parts
    content {
      filename     = part.value.filename
      content_type = part.value.content_type
      content      = part.value.content
    }
  }
}

resource "tailscale_tailnet_key" "default" {
  reusable      = var.reusable
  ephemeral     = var.ephemeral
  preauthorized = var.preauthorized
  expiry        = var.expiry

  # A device is automatically tagged when it is authenticated with this key.
  tags = local.tailscale_tags
}