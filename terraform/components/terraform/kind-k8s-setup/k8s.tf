module "flux_bootstrap" {
  source = "../modules/flux-bootstrap"

  cluster_path                  = var.flux_cluster_path
  git_url                       = var.flux_git_url
  git_ref                       = var.flux_git_ref
  sops_gpg_private_key          = file(var.sops_gpg_private_key_file)
  tailscale_oauth_client_id     = local.oauth_client_id
  tailscale_oauth_client_secret = local.oauth_client_secret
}
