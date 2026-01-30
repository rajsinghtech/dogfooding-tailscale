provider "google" {
  project = local.project_id
  region  = local.region
  zone    = local.zone
}

provider "google-beta" {
  project = local.project_id
  region  = local.region
  zone    = local.zone
}

// VPC with GKE subnets and NAT configuration
module "vpc" {
  source = "../modules/google-vpc"

  project_id = local.project_id
  region     = local.region
  name       = local.name

  # Enable router and NAT
  create_router                       = true
  create_nat                          = true
  router_name                         = format("%s-router", local.name)
  enable_endpoint_independent_mapping = var.enable_endpoint_independent_mapping

  # Configure subnets with proper structure
  subnets = [
    # Main VPC subnet
    {
      subnet_name           = format("%s-subnet", local.name)
      subnet_ip             = var.vpc_subnet_cidr
      subnet_region         = local.region
      subnet_private_access = true
      subnet_flow_logs      = true
      subnet_tags           = [for k, v in local.tags : "${k}-${v}" if v != ""]
    },
    # GKE subnet
    {
      subnet_name           = format("%s-gke-subnet", local.name)
      subnet_ip             = var.gke_subnet_cidr
      subnet_region         = local.region
      subnet_private_access = true
      subnet_flow_logs      = true
      subnet_tags           = [for k, v in local.tags : "${k}-${v}" if v != ""]
    }
  ]

  # Secondary IP ranges for GKE
  secondary_ranges = {
    "${local.name}-gke-subnet" = [
      {
        range_name    = format("%s-pod-range", local.name)
        ip_cidr_range = var.gke_pod_range_cidr
      },
      {
        range_name    = format("%s-service-range", local.name)
        ip_cidr_range = var.gke_service_range_cidr
      }
    ]
  }
}


resource "google_container_cluster" "primary" {
  name     = local.gke_cluster_name
  location = local.region

  deletion_protection = false
  min_master_version  = var.kubernetes_version

  # Add labels to GKE cluster
  resource_labels = local.tags

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = module.vpc.vpc_id
  subnetwork = module.vpc.subnets["${local.region}/${local.name}-gke-subnet"].self_link

  datapath_provider = "ADVANCED_DATAPATH" # This enables GKE Dataplane V2 with default CNI

  ip_allocation_policy {
    cluster_secondary_range_name  = format("%s-pod-range", local.name)
    services_secondary_range_name = format("%s-service-range", local.name)
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${local.project_id}.svc.id.goog"
  }

  # Enable Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Private cluster config
  private_cluster_config {
    enable_private_nodes    = local.enable_private_endpoint
    enable_private_endpoint = local.enable_private_endpoint
    master_ipv4_cidr_block  = var.gke_master_cidr
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Configure master authorized networks when using private endpoint
  dynamic "master_authorized_networks_config" {
    for_each = local.enable_private_endpoint ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr
          display_name = cidr_blocks.value.name
        }
      }
    }
  }

  depends_on = [
    module.vpc
  ]
}

resource "google_container_node_pool" "primary_nodes" {
  name       = format("%s-node-pool", local.name)
  location   = local.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  # Add labels to node pool
  node_locations = [local.zone]

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"

    # Add labels to node config
    labels          = local.tags
    resource_labels = local.tags

    # Add metadata for tags and disable legacy endpoints
    metadata = merge(
      {
        disable-legacy-endpoints = "true"
      },
      local.tags
    )

    dynamic "kubelet_config" {
      for_each = var.kubelet_config != {} ? [var.kubelet_config] : []
      content {
        cpu_manager_policy   = kubelet_config.value.cpu_manager_policy
        cpu_cfs_quota        = kubelet_config.value.cpu_cfs_quota
        cpu_cfs_quota_period = kubelet_config.value.cpu_cfs_quota_period
        pod_pids_limit       = kubelet_config.value.pod_pids_limit
      }
    }

    # Google recommends custom service accounts with minimal permissions
    service_account = var.service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Enable workload identity on the nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Add tags to identify nodes in the VPC network
    tags = ["gke-node", format("%s-nodes", local.name)]
  }

  # Add management settings to control node updates
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Configure rolling updates for node pool

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}
