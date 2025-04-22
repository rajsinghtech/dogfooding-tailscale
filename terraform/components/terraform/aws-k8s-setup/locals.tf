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
  tenant                        = var.tenant
  environment                   = var.environment
  stage                         = var.stage
  region                        = var.region
  connector_cidr                = var.connector_cidr
  argo_repo_url                 = var.argo_repo_url
  argo_config_path               = var.argo_config_path
  name                          = data.terraform_remote_state.aws_tfstate.outputs.name
  enable_sr                     = data.terraform_remote_state.aws_tfstate.outputs.enable_sr
  sr_instance_hostname          = data.terraform_remote_state.aws_tfstate.outputs.sr_instance_hostname
  vpc_cidr                      = data.terraform_remote_state.aws_tfstate.outputs.vpc_cidr
  cluster_service_ipv4_cidr     = data.terraform_remote_state.aws_tfstate.outputs.cluster_service_ipv4_cidr
  cluster_name                  = data.terraform_remote_state.aws_tfstate.outputs.cluster_name
  key_name                      = data.terraform_remote_state.aws_tfstate.outputs.ssh_keyname
  eks_cluster_endpoint          = data.terraform_remote_state.aws_tfstate.outputs.eks_cluster_endpoint
  eks_cluster_ca_certificate     = base64decode(data.terraform_remote_state.aws_tfstate.outputs.eks_cluster_ca_certificate)
  eks_cluster_auth_token        = data.aws_eks_cluster_auth.this.token
  oauth_client_id               = data.terraform_remote_state.aws_tfstate.outputs.oauth_client_id
  oauth_client_secret           = data.terraform_remote_state.aws_tfstate.outputs.oauth_client_secret
  eks_ebs_csi_iam_role_arn      = data.terraform_remote_state.aws_tfstate.outputs.ebs_csi_iam_role_arn
  aws_lb_controller_iam_role_arn = data.terraform_remote_state.aws_tfstate.outputs.aws_lb_controller_iam_role_arn
}