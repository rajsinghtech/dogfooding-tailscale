variable "tenant" {
  description = "Name of the user/tenant for the Atmos Stack"
  type        = string
}

variable "environment" {
  description = "Short-form name of the environment for the Atmos Stack"
  type        = string
}

variable "stage" {
  description = "Name of stage"
  type        = string
}

variable "oauth_client_id" {
  description = "OAuth client ID with the tailnets scope in the creating tailnet"
  type        = string
  sensitive   = true
}

variable "oauth_client_secret" {
  description = "OAuth client secret with the tailnets scope in the creating tailnet"
  type        = string
  sensitive   = true
}
