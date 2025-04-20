output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.k3s.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.k3s.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.k3s.private_ip
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = local.vpc_cidr
}

output "tailscale_hostname" {
  description = "Tailscale hostname of the instance"
  value       = local.instance_hostname
}

output "k3s_kubeconfig_command" {
  description = "Command to get kubeconfig from the instance"
  value       = "ssh -i <path-to-key.pem> ubuntu@${aws_instance.k3s.public_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml' > kubeconfig.yaml"
}

output "tailscale_access_instructions" {
  description = "Instructions for accessing the K3s instance via Tailscale"
  value       = "Once the instance is authorized in your Tailscale admin console, you can access it using: ssh ubuntu@${local.instance_hostname}"
}

output "demo_app_access_instructions" {
  description = "Instructions for accessing the demo application"
  value       = "After connecting to the K3s node via Tailscale, access the demo app with: curl http://${aws_instance.k3s.private_ip}:8080"
} 