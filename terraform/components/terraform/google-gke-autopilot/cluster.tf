locals {
  name = var.cluster_name
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Create a VPC network
resource "google_compute_network" "vpc" {
  name                    = "${local.name}-vpc"
  auto_create_subnetworks = false

  # Add description for tagging
  description = join(", ", [
    for k, v in var.tags : "${k}=${v}"
  ])
}

# Create a subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${local.name}-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.id

  # Add description for tagging
  description = join(", ", [
    for k, v in var.tags : "${k}=${v}"
  ])
}

# Create a firewall rule to allow access to kube-apiserver
# Remove the firewall rule since we're using master_authorized_networks_config

# Create the GKE Autopilot cluster
resource "google_container_cluster" "primary" {
  name = local.name

  location                 = var.region
  enable_autopilot         = true
  enable_l4_ilb_subsetting = true

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.1.0.0/16"
    services_ipv4_cidr_block = "10.2.0.0/16"
  }

  # Configure the cluster to use the network
  network = google_compute_network.vpc.id

  # Configure the cluster to use the subnet
  subnetwork = google_compute_subnetwork.subnet.self_link

  # Add tags to the cluster
  resource_labels = var.tags

  # Enable master authorized networks
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.key
        display_name = cidr_blocks.value
      }
    }
  }

  deletion_protection = false

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}
