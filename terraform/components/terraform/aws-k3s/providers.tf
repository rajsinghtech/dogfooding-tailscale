provider "aws" {
  region = var.region
}

provider "tailscale" {
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret
} 