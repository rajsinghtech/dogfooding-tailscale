variable "tenant" {
  description = "Name of the user/tenant for the Atmos Stack"
  type        = string
}

variable "environment" {
  description = "Short-form name of the region for the Atmos Stack"
  type        = string
}

variable "stage" {
  description = "Name of stage"
  type        = string
}

variable "region" {
  description = "AWS Region of cluster"
  type        = string
}

variable "connector_cidr" {
  description = "Connector CIDR"
  type        = string
}

variable "argo_repo_url" {
  description = "Argo repo URL"
  type        = string
}

variable "argo_config_path" {
  description = "Connector CIDR"
  type        = string
}

