resource "google_compute_address" "client_nat" {
  for_each = var.clients

  name         = format("%s-%s-nat-ip", local.name, each.key)
  region       = each.value.region
  network_tier = "STANDARD"
}

module "client_vpc" {
  source   = "../modules/google-vpc"
  for_each = var.clients

  project_id = var.gcp_project_id
  region     = each.value.region
  name       = format("%s-%s", local.name, each.key)

  create_router                       = true
  create_nat                          = true
  enable_endpoint_independent_mapping = false
  nat_ips                             = [google_compute_address.client_nat[each.key].self_link]

  subnets = [
    {
      subnet_name   = format("%s-%s", local.name, each.key)
      subnet_ip     = each.value.subnet_cidr
      subnet_region = each.value.region
    }
  ]
}

module "client_tailscale" {
  source   = "../modules/cloudinit-ts"
  for_each = var.clients

  hostname      = format("%s-client-%s", local.name, each.key)
  primary_tag   = "pr-client"
  enable_ssh    = true
  reusable      = true
  ephemeral     = true
  track         = var.tailscale_track
  base64_encode = false

  additional_parts = [
    {
      filename     = "install_iperf3.sh"
      content_type = "text/x-shellscript"
      content      = local.iperf3_install_script
    },
    {
      filename     = "never_direct_udp.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOT
        #!/bin/bash
        set -e
        echo 'TS_DEBUG_NEVER_DIRECT_UDP=true' >> /etc/default/tailscaled
        systemctl restart tailscaled
      EOT
    }
  ]
}

resource "google_compute_instance" "client" {
  for_each = var.clients

  name         = format("%s-client-%s", local.name, each.key)
  machine_type = var.client_machine_type
  zone         = each.value.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }

  network_interface {
    subnetwork = module.client_vpc[each.key].subnets[format("%s/%s-%s", each.value.region, local.name, each.key)].self_link
  }

  metadata = {
    user-data = module.client_tailscale[each.key].rendered
  }

  labels = {
    tenant = var.tenant
    stage  = var.stage
  }
}
