data "terraform_remote_state" "kind_tfstate" {
  backend = "local"
  config = {
    path = "${path.root}/../kind/terraform.tfstate.d/${var.tenant}-${var.environment}-${var.stage}/terraform.tfstate"
  }
}

locals {
  endpoint               = data.terraform_remote_state.kind_tfstate.outputs.endpoint
  client_certificate     = data.terraform_remote_state.kind_tfstate.outputs.client_certificate
  client_key             = data.terraform_remote_state.kind_tfstate.outputs.client_key
  cluster_ca_certificate = data.terraform_remote_state.kind_tfstate.outputs.cluster_ca_certificate
  oauth_client_id        = data.terraform_remote_state.kind_tfstate.outputs.oauth_client_id
  oauth_client_secret    = data.terraform_remote_state.kind_tfstate.outputs.oauth_client_secret
}
