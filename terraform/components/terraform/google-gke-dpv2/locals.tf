#########################################################################################
# All vars declared as locals for consistency in referencing in the resources (cuz OCD) #
#########################################################################################

locals {
  tenant       = var.tenant
  environment  = var.environment
  stage        = var.stage
  cluster_name = var.cluster_name
  project_id   = var.project_id
  region       = var.region
  zone         = var.zone

  # Naming patterns
  name             = format("%s-%s-%s", local.tenant, local.environment, local.stage)
  gke_cluster_name = format("%s-%s-%s-%s", local.tenant, local.cluster_name, local.environment, local.stage)

  # Subnet router configuration
  sr_instance_hostname    = var.sr_instance_hostname
  enable_sr               = var.enable_sr
  enable_private_endpoint = var.enable_private_endpoint
  sr_mig_desired_size     = var.sr_mig_desired_size

  # OAuth credentials for Tailscale
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret

  # Tags with standard enrichment (GCP requires lowercase label keys)
  tags = merge(var.tags, { "region" = var.region }, { "tenant-prefix" = var.tenant }, { "env" = var.environment }, { "stage" = var.stage })

  # All subnet CIDRs to advertise via Tailscale (VPC subnets + GKE secondary ranges + master CIDR)
  vpc_subnets = concat(
    [var.vpc_subnet_cidr, var.gke_subnet_cidr],
    [var.gke_pod_range_cidr, var.gke_service_range_cidr],
    local.enable_private_endpoint ? [var.gke_master_cidr] : []
  )

  # Combine VPC subnets with user-provided routes, removing any duplicates
  all_advertised_routes = distinct(concat(local.vpc_subnets, var.advertise_routes))
}
