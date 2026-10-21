provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

provider "google" {
  project = var.gcp_project_id
}

provider "tailscale" {
  api_key = var.tailscale_api_key
}
