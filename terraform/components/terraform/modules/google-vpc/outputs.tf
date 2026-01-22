output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.network_id
}

output "vpc_self_link" {
  description = "The URI of the VPC"
  value       = module.vpc.network_self_link
}

output "subnets" {
  description = "A map of subnet names to subnet details"
  value       = module.vpc.subnets
}

output "subnets_ips" {
  description = "A map of subnet names to subnet IP ranges"
  value       = module.vpc.subnets_ips
}

output "subnets_self_links" {
  description = "A list of subnet self-links in the order they were defined"
  value       = module.vpc.subnets_self_links
}

output "subnets_secondary_ranges" {
  description = "A map of subnet names to their secondary ranges"
  value       = module.vpc.subnets_secondary_ranges
}

output "secondary_ranges" {
  description = "The secondary ranges configured for the subnets"
  value       = var.secondary_ranges
}

output "nat_ips" {
  description = "List of NAT IPs for the Cloud Router"
  value       = length(module.cloud_router) > 0 ? module.cloud_router[0].nat_ips : []
}

output "nat_ids" {
  description = "List of NAT IDs for the Cloud Router"
  value       = length(module.cloud_router) > 0 ? [for nat in module.cloud_router[0].nat : nat.id] : []
}
