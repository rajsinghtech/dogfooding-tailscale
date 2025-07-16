################################################################################
# Data sources and Provider Initialization                                     #
################################################################################

# Set AWS region
provider "aws" {
  region = local.region
}

# Initialize the tailscale provider 
provider "tailscale" {
  oauth_client_id     = local.oauth_client_id
  oauth_client_secret = local.oauth_client_secret
}

# Get list of available AZs in our region
data "aws_availability_zones" "available" {}

# Cluster auth datasource
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

################################################################################
# EKS Cluster                                                                  #
################################################################################

module "eks" {
  enable_irsa = true
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name                    = local.name
  cluster_version                 = local.cluster_version
  cluster_endpoint_public_access  = local.cluster_endpoint_public_access
  cluster_endpoint_private_access = local.cluster_endpoint_private_access
  
  enable_cluster_creator_admin_permissions = true
  
  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    metrics-server         = {}   
  }

  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  vpc_id                    = module.vpc.vpc_id
  subnet_ids = local.public_workers ? slice(module.vpc.public_subnets, 0, length(local.azs)) : slice(module.vpc.private_subnets, 0, length(local.azs))
  cluster_service_ipv4_cidr = local.cluster_service_ipv4_cidr

  eks_managed_node_groups = {
    "${local.name}-wg" = {
      instance_types = [local.cluster_worker_instance_type]
      node_group_name_prefix = "${local.name}-wg"

      min_size     = local.min_cluster_worker_count
      max_size     = local.max_cluster_worker_count
      desired_size = local.desired_cluster_worker_count
      
      disk_size = local.cluster_worker_boot_disk_size

      # Associate public IP if public_workers is true
      associate_public_ip_address = local.public_workers

      key_name = local.key_name

      pre_bootstrap_user_data = <<-EOT
        yum install -y amazon-ssm-agent kernel-devel-`uname -r`
        systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
      EOT

      tags = merge(
        local.tags,
        { 
          "Name" = "${local.name}-worker"
        }
      )
    }
  }

  node_security_group_additional_rules = {
    ingress_to_metrics_server = {
      description                   = "Cluster API to metrics-server"
      protocol                      = "tcp"
      from_port                     = 30000
      to_port                       = 30000
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_self_all = {
      description = "Allow all traffic within the worker-node security group"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      protocol    = "-1"
      self        = true
    }
    ingress_vpc_all = {
      description = "Allow all traffic within VPC"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      protocol    = "-1"
      cidr_blocks = [local.vpc_cidr]
    }
  }

  tags = local.tags
}

################################################################################
# IAM Role and Policy for AWS Load Balancer Controller (IRSA)
################################################################################

# IAM Policy for AWS Load Balancer Controller
resource "aws_iam_policy" "aws_lb_controller" {
  name        = "${module.eks.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/../files/aws-iam/aws_lb_controller_iam_policy.json")
}

# IAM Role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_lb_controller" {
  name = "${module.eks.cluster_name}-aws-lb-controller"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(module.eks.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "aws_lb_controller" {
  role       = aws_iam_role.aws_lb_controller.name
  policy_arn = aws_iam_policy.aws_lb_controller.arn
}



################################################################################
# IAM Role and Policy for EBS CSI Driver (IRSA)
################################################################################
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${module.eks.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_policy" "ebs_csi" {
  name        = "${module.eks.cluster_name}-ebs-csi-policy"
  description = "EBS CSI driver policy"
  policy      = file("${path.module}/../files/aws-iam/ebs_csi_iam_policy.json")
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = aws_iam_policy.ebs_csi.arn
}


#########################################################################################
# EC2 to EKS control plane security group access to private kubeapiserver               #
#########################################################################################

resource "aws_security_group_rule" "eks_control_plane_ingress" {
  count                    = local.enable_sr ? 1 : 0
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.main[0].id
  security_group_id        = module.eks.cluster_primary_security_group_id
  description              = "Allow traffic from EC2 SR instance SG to EKS control plane on port 443"
}

#########################################################################################
# TS Split-DNS setup for EKS private-only kube-apiserver FQDN resolution in the tailnet #
#########################################################################################

resource "tailscale_dns_split_nameservers" "eks_route53_resolver" {
  count       = local.public_workers ? 0 : 1
  domain      = "${local.region}.eks.amazonaws.com"
  nameservers = [local.vpc_plus_2_ip]
}

resource "tailscale_dns_split_nameservers" "elb_route53_resolver" {
  count       = local.public_workers ? 0 : 1
  domain      = "elb.${local.region}.amazonaws.com"
  nameservers = [local.vpc_plus_2_ip]
}

resource "tailscale_dns_search_paths" "eks_search_paths" {
  search_paths = [
    "amazonaws.com",
    "svc.cluster.local"
  ]
}