#########################################################################################
# All vars declared as locals for consistency in referencing in the resources (cuz OCD) #
#########################################################################################

locals {
  tenant                = var.tenant
  environment           = var.environment
  stage                 = var.stage
  cluster_name          = var.cluster_name
  aks_cluster_name      = format("%s-%s-%s-%s", local.tenant, local.cluster_name, local.environment, local.stage)
  location              = var.location
  vnet_cidr             = var.vnet_cidr
  aks_service_ipv4_cidr = var.aks_service_ipv4_cidr
  node_count            = var.node_count
  cluster_outbound_type = var.cluster_outbound_type
  aks_version           = var.aks_version
  cluster_vm_size       = var.cluster_vm_size
  vm_size               = var.vm_size
  ssh_private_key_path  = var.ssh_private_key_path
  oauth_client_id       = var.oauth_client_id
  oauth_client_secret   = var.oauth_client_secret
  tags                  = merge(var.tags, { "Region" = var.location }, { "Tenant-Prefix" = var.tenant }, { "Env" = var.environment }, { "Stage" = var.stage })
  sr_instance_hostname  = var.sr_instance_hostname

  # Subnet slicing logic
  public_subnets  = [for k in range(3) : cidrsubnet(local.vnet_cidr, 4, k)]
  private_subnets = [for k in range(3) : cidrsubnet(local.vnet_cidr, 4, k + 10)]
  # DNS resolver inbound subnet must be /24 or smaller
  dns_inbound_subnet = cidrsubnet(local.vnet_cidr, 8, 255)

  # Tailscale advertise routes (private subnets, user routes)
  advertise_routes = distinct(concat([local.vnet_cidr], coalesce(var.advertise_routes, [])))

  # Subnet router VMSS configuration
  enable_sr            = var.enable_sr
  sr_vmss_desired_size = var.sr_vmss_desired_size
}
