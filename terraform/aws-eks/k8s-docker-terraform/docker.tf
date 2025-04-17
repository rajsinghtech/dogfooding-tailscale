# Docker provider configuration using SSH to the EC2 instance
provider "docker" {
  host     = "ssh://ubuntu@${local.aws_instance_client_public_ip}"
  # Unfortunately atm, we have no easy way to add host key to ~/.ssh/known_hosts for this provider to not complain and fail when connecting to our instance over SSH
  # So we disable host key checking to make it work. I REALLY hate this kind of bs with TF providers.
  ssh_opts = ["-i", "~/.ssh/${local.key_name}.pem", "-o", "StrictHostKeyChecking=no"]
}

# Grab the latest nginx image digest
resource "docker_image" "nginx" {
  name = "nginx:latest"
}

# NGINX Docker container setup (using the nginx.conf copied by remote-exec-provisioner)
resource "docker_container" "nginx" {
  name  = "nginx_server"
  image = docker_image.nginx.image_id
  ports {
    internal = 80
    external = 80
  }
  volumes {
    container_path = "/etc/nginx/nginx.conf"
    host_path      = "/home/ubuntu/nginx_docker/nginx.conf" 
  }
  restart = "unless-stopped"
  lifecycle {
    # This provider hates reconciling state so this is the hack workaround to not make it recreate the container on subsequent terraform applies
    ignore_changes = [env, dns, dns_search, domainname, network_mode, working_dir, labels, cpu_shares, memory, memory_swap]
  }
}