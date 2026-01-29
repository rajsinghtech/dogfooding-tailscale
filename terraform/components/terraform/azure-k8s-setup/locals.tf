# Grab tfstate information from phase-1 (Azure)
data "terraform_remote_state" "azure_tfstate" {
  backend = "local"
  config = {
    path = "${path.root}/../azure-aks/terraform.tfstate.d/${local.tenant}-${local.environment}-${local.stage}/terraform.tfstate"
  }
}

#######################################################################
# Define locals from outputs of the state file to be used in this run #
#######################################################################

locals {
  tenant                         = var.tenant
  environment                    = var.environment
  stage                          = var.stage
  location                       = var.location
  cluster_name                   = data.terraform_remote_state.azure_tfstate.outputs.cluster_name
  resource_group_name            = data.terraform_remote_state.azure_tfstate.outputs.resource_group_name
  aks_cluster_host               = data.terraform_remote_state.azure_tfstate.outputs.aks_cluster_host
  aks_cluster_ca_certificate     = base64decode(data.terraform_remote_state.azure_tfstate.outputs.aks_cluster_ca_certificate)
  aks_cluster_client_key         = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config[0].client_key)
  aks_cluster_client_certificate = base64decode(data.azurerm_kubernetes_cluster.credentials.kube_admin_config[0].client_certificate)
  oauth_client_id                = data.terraform_remote_state.azure_tfstate.outputs.oauth_client_id
  oauth_client_secret            = data.terraform_remote_state.azure_tfstate.outputs.oauth_client_secret
}
