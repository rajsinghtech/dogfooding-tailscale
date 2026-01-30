# Tailscale provider for subnet router
provider "tailscale" {
  oauth_client_id     = local.oauth_client_id
  oauth_client_secret = local.oauth_client_secret
}

# Generate cloud-init configuration for Tailscale subnet router
module "cloudinit_config" {
  count             = local.enable_sr ? local.sr_mig_desired_size : 0
  source            = "../modules/cloudinit-ts"
  hostname          = "${local.sr_instance_hostname}-${count.index + 1}"
  accept_routes     = var.sr_accept_routes
  enable_ssh        = var.sr_enable_ssh
  ephemeral         = var.sr_ephemeral
  reusable          = var.sr_reusable
  advertise_routes  = local.all_advertised_routes
  primary_tag       = var.sr_primary_tag
  additional_tags   = ["infra"]
  track             = var.tailscale_track
  relay_server_port = var.tailscale_relay_server_port
}

# Instance template for subnet router MIG
resource "google_compute_instance_template" "sr" {
  count          = local.enable_sr ? 1 : 0
  name_prefix    = format("%s-sr-", local.name)
  machine_type   = var.machine_type
  region         = local.region
  can_ip_forward = true

  disk {
    source_image = "projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20250312"
    disk_size_gb = 10
    disk_type    = "pd-balanced"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = module.vpc.subnets["${local.region}/${local.name}-gke-subnet"].self_link

    access_config {
      // Ephemeral public IP
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-osconfig = "TRUE"
    user-data       = base64decode(module.cloudinit_config[0].rendered)
    ssh-keys        = join("\n", var.ssh_public_keys)
  }

  labels = {
    managed-by = "terraform"
    purpose    = "gce-sr-instance"
    name       = local.sr_instance_hostname
  }

  tags = ["gce-sr"]

  lifecycle {
    create_before_destroy = true
  }
}

# Managed Instance Group for subnet router
resource "google_compute_instance_group_manager" "sr" {
  count              = local.enable_sr ? 1 : 0
  name               = format("%s-sr-mig", local.name)
  base_instance_name = format("%s-sr", local.name)
  zone               = local.zone
  target_size        = local.sr_mig_desired_size

  version {
    instance_template = google_compute_instance_template.sr[0].self_link
  }

  named_port {
    name = "tailscale"
    port = 41641
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Use external data source to get MIG instance public IPs
data "external" "mig_ips" {
  count   = local.enable_sr ? 1 : 0
  program = ["bash", "-c", "ips=$(gcloud compute instances list --filter='name~${format("%s-sr", local.name)}' --format='value(networkInterfaces[0].accessConfigs[0].natIP)' --project=${local.project_id} 2>/dev/null | tr '\\n' ',' | sed 's/,$//'); echo \"{\\\"ips\\\": \\\"$ips\\\"}\""]

  depends_on = [google_compute_instance_group_manager.sr]
}

# Firewall rules for subnet router VM
resource "google_compute_firewall" "subnet_router_ingress" {
  name    = format("%s-subnet-router-ingress", local.name)
  network = module.vpc.vpc_id

  allow {
    protocol = "udp"
    ports    = ["41641"]
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gce-sr"]
}

resource "google_compute_firewall" "subnet_router_ingress_ipv6" {
  name    = format("%s-subnet-router-ingress-ipv6", local.name)
  network = module.vpc.vpc_id

  allow {
    protocol = "udp"
    ports    = ["41641"]
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["::/0"]
  target_tags   = ["gce-sr"]
}

resource "google_compute_firewall" "tailscale_relay_ipv4" {
  count   = local.enable_sr && var.tailscale_relay_server_port != null ? 1 : 0
  name    = format("%s-tailscale-relay-ipv4", local.name)
  network = module.vpc.vpc_id

  allow {
    protocol = "udp"
    ports    = [tostring(var.tailscale_relay_server_port)]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gce-sr"]
}

resource "google_compute_firewall" "tailscale_relay_ipv6" {
  count   = local.enable_sr && var.tailscale_relay_server_port != null ? 1 : 0
  name    = format("%s-tailscale-relay-ipv6", local.name)
  network = module.vpc.vpc_id

  allow {
    protocol = "udp"
    ports    = [tostring(var.tailscale_relay_server_port)]
  }

  source_ranges = ["::/0"]
  target_tags   = ["gce-sr"]
}

# Ops Agent configuration
module "ops_agent_policy" {
  count         = local.enable_sr ? 1 : 0
  source        = "terraform-google-modules/cloud-operations/google//modules/ops-agent-policy"
  version       = "~> 0.6"
  project       = local.project_id
  zone          = local.zone
  assignment_id = format("%s-ops-agent-policy", local.name)

  agents_rule = {
    package_state = "installed"
    version       = "latest"
  }

  instance_filter = {
    all = false
    inclusion_labels = [
      {
        labels = {
          purpose = "gce-sr-instance"
        }
      }
    ]
  }

  depends_on = [google_compute_instance_group_manager.sr]
}
