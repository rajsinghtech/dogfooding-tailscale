locals {
  # Create a map of subnets with their secondary ranges
  subnets_with_secondaries = [
    for subnet in var.subnets : merge(subnet, {
      secondary_ip_ranges = lookup(var.secondary_ranges, subnet.subnet_name, [])
    })
  ]
}

module "vpc" {
  # https://registry.terraform.io/modules/terraform-google-modules/network/google/latest
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id   = var.project_id
  network_name = var.name

  # Configure subnets with secondary ranges
  subnets = [
    for subnet in local.subnets_with_secondaries : {
      subnet_name           = subnet.subnet_name
      subnet_ip             = subnet.subnet_ip
      subnet_region         = subnet.subnet_region
      subnet_private_access = lookup(subnet, "subnet_private_access", false)
      subnet_flow_logs      = lookup(subnet, "subnet_flow_logs", false)

      # Add secondary ranges if they exist
      secondary_ip_ranges = [
        for range in subnet.secondary_ip_ranges : {
          range_name    = range.range_name
          ip_cidr_range = range.ip_cidr_range
        }
      ]
    }
  ]
}

module "cloud_router" {
  # https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google/latest
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 7.0"

  count = var.create_router ? 1 : 0

  project = var.project_id
  region  = var.region

  name    = coalesce(var.router_name, "${var.name}-router")
  network = module.vpc.network_name

  nats = var.create_nat ? [{
    name                               = "${var.name}-nat"
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

    # Include all GKE subnets (primary and secondary ranges)
    subnetworks = [
      for subnet in local.subnets_with_secondaries : {
        name = subnet.subnet_name
        source_ip_ranges_to_nat = concat(
          ["PRIMARY_IP_RANGE"],
          length(subnet.secondary_ip_ranges) > 0 ? ["LIST_OF_SECONDARY_IP_RANGES"] : []
        )
        secondary_ip_range_names = [
          for range in subnet.secondary_ip_ranges : range.range_name
        ]
      }
    ]
  }] : []
}
