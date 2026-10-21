module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = [format("%sa", var.region)]
  private_subnets = [cidrsubnet(var.vpc_cidr, 8, 0)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 8, 1)]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_ip_ranges" "route53_healthchecks" {
  services = ["route53_healthchecks"]
}

resource "aws_security_group" "relay" {
  #checkov:skip=CKV_AWS_382:Egress to 0.0.0.0/0 required for Tailscale connectivity to control and DERP
  name        = format("%s-relay-sg", local.name)
  vpc_id      = module.vpc.vpc_id
  description = "Tailscale peer relay"

  ingress {
    from_port   = var.relay_port
    to_port     = var.relay_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Tailscale peer relay"
  }

  dynamic "ingress" {
    for_each = local.ga_enabled ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = data.aws_ip_ranges.route53_healthchecks.cidr_blocks
      description = "Global Accelerator health checks"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.tags, { "Name" = format("%s-relay-sg", local.name) })
}

module "relay_tailscale" {
  source = "../modules/cloudinit-ts"

  hostname                    = format("%s-relay", local.name)
  primary_tag                 = "pr-relay"
  enable_ssh                  = true
  reusable                    = true
  ephemeral                   = true
  track                       = var.tailscale_track
  peer_relay_port             = local.relay_enabled ? var.relay_port : null
  peer_relay_static_endpoints = local.ga_endpoints
}

resource "aws_instance" "relay" {
  #checkov:skip=CKV_AWS_88:Public IP required for the public relay_mode
  #checkov:skip=CKV_AWS_126:Detailed monitoring not needed for lab environment
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.relay_instance_type
  subnet_id                   = local.ga_enabled ? module.vpc.private_subnets[0] : module.vpc.public_subnets[0]
  associate_public_ip_address = !local.ga_enabled
  vpc_security_group_ids      = [aws_security_group.relay.id]
  ebs_optimized               = true
  user_data_base64            = module.relay_tailscale.rendered
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.tags, { "Name" = format("%s-relay", local.name) })
}

resource "aws_globalaccelerator_accelerator" "relay" {
  count = local.ga_enabled ? 1 : 0

  name            = format("%s-relay-ga", local.name)
  ip_address_type = "IPV4"
  enabled         = true

  tags = local.tags
}

resource "aws_globalaccelerator_listener" "relay" {
  count = local.ga_enabled ? 1 : 0

  accelerator_arn = aws_globalaccelerator_accelerator.relay[0].arn
  protocol        = "UDP"

  port_range {
    from_port = var.relay_port
    to_port   = var.relay_port
  }
}

resource "aws_globalaccelerator_endpoint_group" "relay" {
  count = local.ga_enabled ? 1 : 0

  listener_arn          = aws_globalaccelerator_listener.relay[0].arn
  endpoint_group_region = var.region
  health_check_protocol = "TCP"
  health_check_port     = 22

  endpoint_configuration {
    endpoint_id                    = aws_instance.relay.id
    client_ip_preservation_enabled = true
    weight                         = 100
  }
}
