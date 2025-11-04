variable "enabled" {
  type    = bool
  default = true
}

variable "cert_manager_version" {
  type    = string
  default = "v1.11.0"
}

variable "helm_values" {
  type    = any
  default = {}
}

