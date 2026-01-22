locals {
  enabled = true

  name = var.name

  vpc_cidr = var.vpc_cidr

  instance_type    = var.instance_type
  root_volume_size = var.root_volume_size

  # Tailscale variables
  instance_hostname = var.instance_hostname
  advertise_routes  = concat([var.vpc_cidr], var.advertise_routes)
  tailscale_tags    = var.tailscale_tags

  key_name = var.ssh_keyname

  tags = merge(
    var.tags,
    {
      "terraform/component" = "aws-k3s"
    }
  )
} 