variable "os_user_name" {
  type        = string
  description = "OpenStack user name"
}

variable "os_password" {
  type        = string
  description = "OpenStack password"
  sensitive   = true
}

variable "os_auth_url" {
  type        = string
  description = "OpenStack auth URL"
}

variable "os_tenant_name" {
  type        = string
  description = "OpenStack tenant/project name"
}
