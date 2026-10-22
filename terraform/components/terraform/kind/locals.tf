data "terraform_remote_state" "tailnet_tfstate" {
  backend = "local"
  config = {
    path = "${path.root}/../tailnet/terraform.tfstate.d/${var.tenant}-${var.environment}-${var.stage}/terraform.tfstate"
  }
}

locals {
  tailnet_id          = data.terraform_remote_state.tailnet_tfstate.outputs.tailnet_id
  oauth_client_id     = data.terraform_remote_state.tailnet_tfstate.outputs.oauth_client_id
  oauth_client_secret = data.terraform_remote_state.tailnet_tfstate.outputs.oauth_client_secret
}
