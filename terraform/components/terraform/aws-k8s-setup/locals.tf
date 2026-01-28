# Grab tfstate information from phase-1
data "terraform_remote_state" "aws_tfstate" {
  backend = "local"
  config = {
    path = "${path.root}/../aws-eks/terraform.tfstate.d/${local.tenant}-${local.environment}-${local.stage}/terraform.tfstate"
  }
}

#######################################################################
# Define locals from outputs of the state file to be used in this run #
#######################################################################

locals {
  tenant                         = var.tenant
  environment                    = var.environment
  stage                          = var.stage
  region                         = var.region
  cluster_name                   = data.terraform_remote_state.aws_tfstate.outputs.cluster_name
  vpc_id                         = data.terraform_remote_state.aws_tfstate.outputs.vpc_id
  eks_cluster_endpoint           = data.terraform_remote_state.aws_tfstate.outputs.eks_cluster_endpoint
  eks_cluster_ca_certificate     = base64decode(data.terraform_remote_state.aws_tfstate.outputs.eks_cluster_ca_certificate)
  eks_cluster_auth_token         = data.aws_eks_cluster_auth.this.token
  oauth_client_id                = data.terraform_remote_state.aws_tfstate.outputs.oauth_client_id
  oauth_client_secret            = data.terraform_remote_state.aws_tfstate.outputs.oauth_client_secret
  eks_ebs_csi_iam_role_arn       = data.terraform_remote_state.aws_tfstate.outputs.ebs_csi_iam_role_arn
  aws_lb_controller_iam_role_arn = data.terraform_remote_state.aws_tfstate.outputs.aws_lb_controller_iam_role_arn
}