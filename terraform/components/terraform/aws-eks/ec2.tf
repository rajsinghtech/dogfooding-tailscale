# Use the module to add the EC2 instance into our tailnet
module "ubuntu-tailscale-client" {
  count         = local.enable_sr ? 1 : 0
  source        = "../modules/cloudinit-ts"
  hostname      = local.sr_instance_hostname
  accept_routes = true
  enable_ssh    = true
  advertise_routes = local.advertise_routes
  primary_tag      = "subnet-router"
}

# Pick the latest Ubuntu 22.04 AMI in the region for our EC2 instance
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

# Allow SSH access via public IP because we're not exploring Tailscale SSH yet (TBD in the future)
resource "aws_security_group" "main" {
  count       = local.enable_sr ? 1 : 0
  vpc_id      = module.vpc.vpc_id
  description = "Required access traffic"
    
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}

# Provision the EC2 instance,pass in templatized base64-encoded cloudinit data from the module that sets up Tailscale client and Docker
resource "aws_instance" "client" {
  count                   = local.enable_sr ? 1 : 0
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = local.sr_ec2_instance_type
  subnet_id               = module.vpc.public_subnets[0]
  vpc_security_group_ids  = [aws_security_group.main[count.index].id]
  source_dest_check       = false
  key_name                = local.key_name
  ebs_optimized           = true

  user_data_base64        = module.ubuntu-tailscale-client[count.index].rendered

  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(
    local.tags,
    {
      "Name" = local.sr_instance_hostname
    }
  )
}