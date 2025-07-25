# Use the module to add the EC2 instance into our tailnet
module "ubuntu-tailscale-client" {
  count         = local.enable_sr ? local.sr_ec2_asg_desired_size : 0
  source        = "../modules/cloudinit-ts"
  hostname      = "${local.sr_instance_hostname}-${count.index + 1}"
  accept_routes = true
  enable_ssh    = true
  ephemeral     = true
  reusable      = true
  advertise_routes = local.advertise_routes
  primary_tag      = "subnet-router"
  track             = var.tailscale_track
  relay_server_port = var.tailscale_relay_server_port
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

  dynamic "ingress" {
    for_each = var.tailscale_relay_server_port != null ? [var.tailscale_relay_server_port] : []
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow Tailscale peer relay server access"
    }
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
# EC2 instance for SR is now managed via an Auto Scaling Group.

resource "aws_launch_template" "sr_ec2" {
  count         = local.enable_sr ? 1 : 0
  name_prefix   = "${local.name}-sr-ec2-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = local.sr_ec2_instance_type
  key_name      = local.key_name

  # User data should be dynamic per instance via cloud-init logic in the module
  user_data = base64encode(element(module.ubuntu-tailscale-client[*].rendered, 0))

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.main[0].id]
    subnet_id                   = module.vpc.public_subnets[0]
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, { "Name" = local.sr_instance_hostname })
  }
}

resource "aws_autoscaling_group" "sr_ec2" {
  count         = local.enable_sr ? 1 : 0
  name                      = "${local.name}-sr-ec2-asg"
  launch_template {
    id      = aws_launch_template.sr_ec2[0].id
    version = "$Latest"
  }
  min_size                  = local.sr_ec2_asg_min_size
  max_size                  = local.sr_ec2_asg_max_size
  desired_capacity          = local.sr_ec2_asg_desired_size
  vpc_zone_identifier       = module.vpc.public_subnets
  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
  tag {
    key                 = "Name"
    value               = local.sr_instance_hostname
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

# This data source will fetch all EC2 instances in the ASG by filtering on the Name tag
# We will use this to output the public IPs for SSH

data "aws_instances" "sr_ec2" {
  filter {
    name   = "tag:Name"
    values = [local.sr_instance_hostname]
  }
}