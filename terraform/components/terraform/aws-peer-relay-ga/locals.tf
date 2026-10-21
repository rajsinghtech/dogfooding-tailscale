locals {
  name = format("%s-%s-%s", var.tenant, var.environment, var.stage)

  relay_enabled = var.relay_mode != "none"
  ga_enabled    = contains(["ga", "both"], var.relay_mode)
  relay_private = var.relay_mode == "ga"

  ga_endpoints = local.ga_enabled ? [
    for ip in aws_globalaccelerator_accelerator.relay[0].ip_sets[0].ip_addresses : format("%s:%d", ip, var.relay_port)
  ] : []

  iperf3_install_script = <<-EOT
    #!/bin/bash
    set -e
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y iperf3 mtr-tiny
  EOT

  tags = merge(
    var.tags,
    {
      "terraform/component" = "aws-peer-relay-ga"
      "Region"              = var.region
      "Tenant-Prefix"       = var.tenant
      "Env"                 = var.environment
      "Stage"               = var.stage
    }
  )
}
