output "name" {
  value     = local.name
  sensitive = true
}

output "ebs_csi_iam_role_arn" {
  description = "IAM Role ARN for EBS CSI driver (for IRSA)"
  value       = aws_iam_role.ebs_csi.arn
}

output "aws_lb_controller_iam_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller (for IRSA)"
  value       = aws_iam_role.aws_lb_controller.arn
}

output "enable_sr" {
  value     = local.enable_sr
  sensitive = true
}

output "eks_auto_mode" {
  description = "Whether EKS Auto Mode is enabled"
  value       = local.eks_auto_mode
}


output "sr_instance_hostname" {
  value     = local.sr_instance_hostname
  sensitive = true
}

output "vpc_cidr" {
  value     = local.vpc_cidr
  sensitive = true
}

output "cluster_service_ipv4_cidr" {
  value     = local.cluster_service_ipv4_cidr
  sensitive = true
}

output "ssh_keyname" {
  value = var.ssh_keyname
  sensitive = true
}

output "eks_cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "eks_cluster_ca_certificate" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "cluster_name" {
  value     = module.eks.cluster_name
  sensitive = true
}

output "eks_cluster_auth_token" {
  value     = data.aws_eks_cluster_auth.this.token
  sensitive = true
}

output "oauth_client_id" {
  value     = local.oauth_client_id
  sensitive = true
}

output "oauth_client_secret" {
  value     = local.oauth_client_secret
  sensitive = true
}

output "sr_ec2_public_ips" {
  value       = data.aws_instances.sr_ec2.public_ips
  description = "Public IPs of all SR EC2 instances"
  sensitive   = true
}

output "Message" {
  description = "Instructions for configuring your environment after Terraform apply."
  value = join("\n", compact([
    "Next Steps:",
    local.eks_auto_mode ? "Cluster Mode: EKS Auto Mode (AWS manages compute, storage, and load balancing)" : "Cluster Mode: Standard EKS with Managed Node Groups",
    "",
    "1. Configure your kubeconfig for kubectl by running:",
    "   aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name} --alias ${module.eks.cluster_name}",
    "",
    "2. Test SSH to each EC2 instance's public IP (Only available if private APIServer endpoint is enabled):",
    local.enable_sr && length(data.aws_instances.sr_ec2.public_ips) > 0 ? join("\n", [
      for idx, ip in data.aws_instances.sr_ec2.public_ips :
        "   ssh -i ~/.ssh/${local.key_name} ubuntu@${ip} # ${local.sr_instance_hostname}-${idx + 1}"
    ]) : "   N/A",
    "",
    "Happy deploying <3"
  ]))
}