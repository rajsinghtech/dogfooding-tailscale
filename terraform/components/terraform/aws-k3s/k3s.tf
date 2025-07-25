# Use the module to add the EC2 instance into our tailnet
module "k3s-tailscale" {
  source            = "../modules/cloudinit-ts"
  hostname          = local.instance_hostname
  accept_routes     = true
  enable_ssh        = true
  advertise_routes  = local.advertise_routes
  primary_tag       = "k3s"
  additional_tags   = []
  track             = var.tailscale_track
  relay_server_port = var.tailscale_relay_server_port
}

# Pick the latest Ubuntu 22.04 AMI in the region
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Security group for the K3s instance
resource "aws_security_group" "k3s" {
  vpc_id      = module.vpc.vpc_id
  description = "Required access traffic for K3s"
    
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access"
  }

  ingress {
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Tailscale WG direct connection access"
  }

  # K3s API server port
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
    description = "Allow K3s API server access"
  }

  # Dynamic ingress for Tailscale relay server port (only when configured)
  dynamic "ingress" {
    for_each = var.tailscale_relay_server_port != null ? [var.tailscale_relay_server_port] : []
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow Tailscale relay server access on port ${ingress.value}"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    local.tags,
    {
      "Name" = "${local.name}-k3s-sg"
    }
  )
}

# Create an additional user-data script to install K3s
locals {
  k3s_install_script = <<-EOT
#!/bin/bash
# Install K3s
curl -sfL https://get.k3s.io | sh -
# Allow non-root access to kubeconfig
sudo mkdir -p /home/ubuntu/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
sudo chown -R ubuntu:ubuntu /home/ubuntu/.kube
sudo sed -i 's/127.0.0.1/0.0.0.0/g' /home/ubuntu/.kube/config
# Install example application
sudo kubectl create namespace demo
cat <<EOF | sudo kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
  namespace: demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: demo
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
EOT
}

# K3s EC2 instance with Tailscale integration
resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.k3s.id]
  source_dest_check      = false
  key_name               = local.key_name
  ebs_optimized          = true

  # Combine the Tailscale cloud-init with the K3s install script
  user_data = <<-EOT
${base64decode(module.k3s-tailscale.rendered)}
${local.k3s_install_script}
EOT

  root_block_device {
    volume_size = local.root_volume_size
    volume_type = "gp3"
  }

  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(
    local.tags,
    {
      "Name" = local.instance_hostname
    }
  )
} 