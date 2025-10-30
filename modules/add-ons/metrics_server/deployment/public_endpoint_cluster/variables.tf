variable "enabled" {
  type    = bool
  default = true
}

variable "metrics_server_chart_version" {
  type    = string
  default = "3.11.0"
}

variable "helm_values" {
  type    = any
  default = {}
}