# Grab tfstate information from phase-1 (Google GKE)
data "terraform_remote_state" "gke_tfstate" {
  backend = "local"
  config = {
    path = "${path.root}/../google-gke-dpv2/terraform.tfstate.d/${local.tenant}-${local.environment}-${local.stage}/terraform.tfstate"
  }
}

#######################################################################
# Define locals from outputs of the state file to be used in this run #
#######################################################################

locals {
  tenant                     = var.tenant
  environment                = var.environment
  stage                      = var.stage
  region                     = var.region
  cluster_name               = data.terraform_remote_state.gke_tfstate.outputs.gke_cluster_name
  project_id                 = data.terraform_remote_state.gke_tfstate.outputs.project_id
  gke_cluster_endpoint       = data.terraform_remote_state.gke_tfstate.outputs.gke_cluster_endpoint
  gke_cluster_ca_certificate = base64decode(data.terraform_remote_state.gke_tfstate.outputs.gke_cluster_ca_certificate)
  oauth_client_id            = data.terraform_remote_state.gke_tfstate.outputs.oauth_client_id
  oauth_client_secret        = data.terraform_remote_state.gke_tfstate.outputs.oauth_client_secret
}
