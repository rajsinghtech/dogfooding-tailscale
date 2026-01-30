module "vpc" {
  # https://registry.terraform.io/modules/terraform-google-modules/network/google/latest
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id   = var.project_id
  network_name = var.name

  subnets = [
    for subnet in var.subnets : {
      subnet_name           = subnet.subnet_name
      subnet_ip             = subnet.subnet_ip
      subnet_region         = subnet.subnet_region
      subnet_private_access = lookup(subnet, "subnet_private_access", false)
      subnet_flow_logs      = lookup(subnet, "subnet_flow_logs", false)
    }
  ]

  secondary_ranges = var.secondary_ranges
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

  depends_on = [module.vpc]

  nats = var.create_nat ? [{
    name                               = "${var.name}-nat"
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

    subnetworks = [
      for subnet in var.subnets : {
        name = module.vpc.subnets["${subnet.subnet_region}/${subnet.subnet_name}"].id
        source_ip_ranges_to_nat = concat(
          ["PRIMARY_IP_RANGE"],
          length(lookup(var.secondary_ranges, subnet.subnet_name, [])) > 0 ? ["LIST_OF_SECONDARY_IP_RANGES"] : []
        )
        secondary_ip_range_names = module.vpc.subnets["${subnet.subnet_region}/${subnet.subnet_name}"].secondary_ip_range[*].range_name
      }
    ]
  }] : []
}
