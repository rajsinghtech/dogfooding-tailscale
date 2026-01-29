#########################################################################################
# All vars declared as locals for consistency in referencing in the resources (cuz OCD) #
#########################################################################################

locals {
  tenant                = var.tenant
  environment           = var.environment
  stage                 = var.stage
  cluster_name          = var.cluster_name
  location              = var.location
  vnet_cidr             = var.vnet_cidr
  aks_service_ipv4_cidr = var.aks_service_ipv4_cidr
  min_count             = var.min_count
  node_count            = var.node_count
  max_count             = var.max_count
  cluster_outbound_type = var.cluster_outbound_type
  ssh_public_key_path   = var.ssh_public_key_path
  ssh_private_key_path  = var.ssh_private_key_path
  aks_version           = var.aks_version
  cluster_vm_size       = var.cluster_vm_size
  vm_size               = var.vm_size
  oauth_client_id       = var.oauth_client_id
  oauth_client_secret   = var.oauth_client_secret
  tags                  = merge(var.tags, { "Region" = var.location }, { "Tenant-Prefix" = var.tenant }, { "Env" = var.environment }, { "Stage" = var.stage })
  hostname              = var.hostname

  # Subnet slicing logic
  public_subnets     = [for k in range(3) : cidrsubnet(local.vnet_cidr, 4, k)]
  private_subnets    = [for k in range(3) : cidrsubnet(local.vnet_cidr, 4, k + 10)]
  dns_inbound_subnet = cidrsubnet(local.vnet_cidr, 4, 15)

  # Tailscale advertise routes (private subnets, user routes)
  advertise_routes = distinct(concat(local.private_subnets, coalesce(var.advertise_routes, [])))

  # Subnet router VMSS configuration
  enable_sr            = var.enable_sr
  sr_vmss_min_size     = var.sr_vmss_min_size
  sr_vmss_max_size     = var.sr_vmss_max_size
  sr_vmss_desired_size = var.sr_vmss_desired_size
}
