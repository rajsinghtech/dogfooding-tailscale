locals {
  # Get all subnets from the VPC
  vpc_subnets = concat(
    [for ip in module.vpc.subnets_ips : ip],  # Get IP ranges from VPC subnets
    [google_compute_subnetwork.gke_subnet.ip_cidr_range],  # Add GKE subnet
    [for r in google_compute_subnetwork.gke_subnet.secondary_ip_range : r.ip_cidr_range]  # Add GKE secondary ranges
  )
  
  # Combine VPC subnets with user-provided routes, removing any duplicates
  all_advertised_routes = distinct(concat(local.vpc_subnets, var.advertise_routes))
}

# Tailscale provider for subnet router
provider "tailscale" {
  oauth_client_id        = var.oauth_client_id
  oauth_client_secret    = var.oauth_client_secret
}

# Generate cloud-init configuration for Tailscale subnet router
module "cloudinit_config" {
  count         = var.enable_sr ? 1 : 0
  source        = "../modules/cloudinit-ts"
  hostname      = "${var.name}-sr-vm"
  accept_routes = true
  enable_ssh    = true
  ephemeral     = false
  reusable      = true
  advertise_routes = local.all_advertised_routes
  primary_tag   = "subnet-router"
  additional_tags = ["infra"]
  track             = var.tailscale_track
  relay_server_port = var.tailscale_relay_server_port
}

resource "google_compute_instance" "gce_sr" {
  count        = var.enable_sr ? 1 : 0
  name         = "${var.name}-sr-vm"
  # Remove hostname as it needs to be FQDN and GCP will auto-generate one
  machine_type = var.machine_type
  zone         = local.zone
  
  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20250312"
      size  = 10
      type  = "pd-balanced"
    }
    auto_delete = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.gke_subnet.self_link
    
    access_config {
      // Ephemeral public IP
    }
  }

  service_account {
    # Use the default compute service account
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
  }

  tags = ["gce-sr"]
}

# Private test VM for internal connectivity testing
resource "google_compute_instance" "pvt_vm_test" {
  count        = var.enable_sr ? 1 : 0
  name         = "${var.name}-pvt-test-vm"
  # Remove hostname as it needs to be FQDN and GCP will auto-generate one
  machine_type = var.machine_type
  zone         = local.zone
  
  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20250312"
      size  = 10
      type  = "pd-balanced"
    }
    auto_delete = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.gke_subnet.self_link
    # No access_config block to ensure no public IP
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-osconfig = "TRUE"
    ssh-keys        = join("\n", var.ssh_public_keys)
    user-data = <<-EOT
      #cloud-config
      packages:
        - netcat
      runcmd:
        - nohup nc -l -k -p 8089 > /dev/null 2>&1 &
    EOT
  }

  labels = {
    managed-by = "terraform"
    purpose    = "pvt-test-vm"
  }

  tags = ["pvt-test-vm"]
}

# Firewall rules for subnet router VM
resource "google_compute_firewall" "subnet_router_ingress" {
  name    = "${var.name}-subnet-router-ingress"
  network = module.vpc.vpc_id

  # Allow Tailscale
  allow {
    protocol = "udp"
    ports    = ["41641"]
  }
  
  # Allow SSH
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Separate IPv4 and IPv6 rules
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gce-sr"]
}

# Separate IPv6 firewall rule for Tailscale
resource "google_compute_firewall" "subnet_router_ingress_ipv6" {
  name    = "${var.name}-subnet-router-ingress-ipv6"
  network = module.vpc.vpc_id

  # Allow Tailscale
  allow {
    protocol = "udp"
    ports    = ["41641"]
  }
  
  # Allow SSH
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["::/0"]
  target_tags   = ["gce-sr"]
}

# Firewall rules for private test VM
resource "google_compute_firewall" "private_vm_ingress" {
  name    = "${var.name}-private-vm-ingress"
  network = module.vpc.vpc_id

  # Allow SSH
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Allow netcat
  allow {
    protocol = "tcp"
    ports    = ["8089"]
  }

  # Allow icmp
  allow {
    protocol = "icmp"
  } 

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["pvt-test-vm"]
}

# Dynamic firewall rule for Tailscale relay server (IPv4)
resource "google_compute_firewall" "tailscale_relay_ipv4" {
  count   = var.enable_sr && var.tailscale_relay_server_port != null ? 1 : 0
  name    = "${var.name}-tailscale-relay-ipv4"
  network = module.vpc.vpc_id

  allow {
    protocol = "udp"
    ports    = [tostring(var.tailscale_relay_server_port)]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gce-sr"]
}

# Dynamic firewall rule for Tailscale relay server (IPv6)
resource "google_compute_firewall" "tailscale_relay_ipv6" {
  count   = var.enable_sr && var.tailscale_relay_server_port != null ? 1 : 0
  name    = "${var.name}-tailscale-relay-ipv6"
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
  count         = var.enable_sr ? 1 : 0
  source        = "github.com/terraform-google-modules/terraform-google-cloud-operations/modules/ops-agent-policy"
  project       = local.project_id
  zone          = local.zone
  assignment_id = "${var.name}-ops-agent-policy"
  
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
      },
      {
        labels = {
          purpose = "pvt-test-vm"
        }
      }
    ]
  }
  
  depends_on = [google_compute_instance.gce_sr[0], google_compute_instance.pvt_vm_test[0]]
}
