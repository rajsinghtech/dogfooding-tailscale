#########################################################################################
# All vars declared as locals for consistency in referencing in the resources (cuz OCD) #
#########################################################################################

locals {
  name                            = var.name
  region                          = var.region
  vpc_cidr                        = var.vpc_cidr
  cluster_service_ipv4_cidr       = var.cluster_service_ipv4_cidr
  key_name                        = var.ssh_keyname
  sr_instance_hostname            = var.sr_instance_hostname
  sr_ec2_instance_type            = var.sr_ec2_instance_type
  sr_ec2_asg_min_size             = var.sr_ec2_asg_min_size
  sr_ec2_asg_max_size             = var.sr_ec2_asg_max_size
  sr_ec2_asg_desired_size         = var.sr_ec2_asg_desired_size
  cluster_worker_instance_type    = var.cluster_worker_instance_type
  min_cluster_worker_count        = var.min_cluster_worker_count
  max_cluster_worker_count        = var.max_cluster_worker_count
  desired_cluster_worker_count    = var.desired_cluster_worker_count
  cluster_worker_boot_disk_size   = var.cluster_worker_boot_disk_size
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_version                 = var.cluster_version
  oauth_client_id                 = var.oauth_client_id
  oauth_client_secret             = var.oauth_client_secret
  public_workers                  = var.public_workers
  tags                            = merge(var.tags, {"Region" = var.region}, {"Tenant-Prefix" = var.tenant}, {"Env" = var.environment}, {"Stage" = var.stage})
  # Select the first 3 availability zones from the available list of AWS AZs. If <3 are available, select them all
  azs                             = slice(data.aws_availability_zones.available.names, 0, min(length(data.aws_availability_zones.available.names), 3))
  # Generate a list of subnets off the VPC CIDR with one private subnet generated per AZ 
  private_subnets                 = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]    
  # Generate a list of subnets off the VPC CIDR with one public subnet per AZ with an offset
  public_subnets                  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 10)]
  # AWS Route 53 Resolver VPC+2 IP 
  vpc_plus_2_ip                   = "${join(".", slice(split(".", var.vpc_cidr), 0, 3))}.2"
  # Merge EKS private subnets CIDRs, AWS Route 53 Resolver IP, and any user-defined routes and advertise them from the subnet router
  # advertise_routes                = distinct(concat(local.private_subnets, coalesce(var.advertise_routes, []), ["${local.vpc_plus_2_ip}/32"]))
  advertise_routes                = var.advertise_routes

  # Enable SR if cluster endpoint is private and not public 
  enable_sr = local.cluster_endpoint_private_access && !local.cluster_endpoint_public_access
}