variable "acl_file" {
  description = "Path to the ACL file (JSON or HuJSON)."
  type        = string
}

variable "acl_format" {
  description = "The format of the ACL file (json or hujson)."
  type        = string
  validation {
    condition     = contains(["json", "hujson"], var.acl_format)
    error_message = "acl_format must be either 'json' or 'hujson'."
  }
}

variable "oauth_client_id" {
  type        = string
  sensitive   = true
  description = <<-EOF
  The OAuth application's ID when using OAuth client credentials.
  Can be set via the TAILSCALE_OAUTH_CLIENT_ID environment variable.
  Both 'oauth_client_id' and 'oauth_client_secret' must be set.
  EOF
}

variable "oauth_client_secret" {
  type        = string
  sensitive   = true
  description = <<-EOF
  (Sensitive) The OAuth application's secret when using OAuth client credentials.
  Can be set via the TAILSCALE_OAUTH_CLIENT_SECRET environment variable.
  Both 'oauth_client_id' and 'oauth_client_secret' must be set.
  EOF
}