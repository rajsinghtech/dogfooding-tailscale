resource "azurerm_kubernetes_cluster" "main" {
  depends_on          = [azurerm_subnet_nat_gateway_association.private, azurerm_nat_gateway_public_ip_association.main]
  name                = format("%s-%s-%s-%s-aks", local.tenant, local.environment, local.stage, local.cluster_name)
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = format("%s-%s-%s-%s", local.tenant, local.environment, local.stage, local.cluster_name)
  kubernetes_version  = local.aks_version
  sku_tier            = "Standard"

  default_node_pool {
    name            = "np1"
    type            = "VirtualMachineScaleSets"
    vm_size         = local.cluster_vm_size
    vnet_subnet_id  = azurerm_subnet.private[0].id
    node_count      = local.node_count
    os_disk_size_gb = 50
    tags            = local.tags

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin    = "azure"
    dns_service_ip    = cidrhost(local.aks_service_ipv4_cidr, 10)
    service_cidr      = local.aks_service_ipv4_cidr
    outbound_type     = local.cluster_outbound_type
    load_balancer_sku = "standard"
  }

  private_cluster_enabled = true
  oidc_issuer_enabled     = true

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

#########################################################################################
# TS Split-DNS setup for AKS private-only kube-apiserver FQDN resolution in the tailnet #
#########################################################################################

resource "tailscale_dns_split_nameservers" "azure_resolver" {
  domain      = "privatelink.${local.location}.azmk8s.io"
  nameservers = [azurerm_private_dns_resolver_inbound_endpoint.main.ip_configurations[0].private_ip_address]
}

resource "tailscale_dns_search_paths" "aks_search_paths" {
  search_paths = [
    "privatelink.${local.location}.azmk8s.io",
    "svc.cluster.local"
  ]
}