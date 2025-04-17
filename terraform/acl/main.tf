locals {
  acl_file_path = "${path.module}/${var.acl_file}"
}

data "local_file" "acl" {
  filename = local.acl_file_path
}

resource "tailscale_acl" "acl" {
  acl = var.acl_format == "json" ? jsonencode(jsondecode(data.local_file.acl.content)) : trimspace(data.local_file.acl.content)
  reset_acl_on_destroy       = true
  overwrite_existing_content = true
}
