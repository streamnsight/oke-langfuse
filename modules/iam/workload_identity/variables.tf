variable "create_policy" {
  default = true
}
variable "compartment_id" {
  type = string
}

variable "workload_name" {
  type = string
}
variable "namespace" {
  type = string
}
variable "service_account_name" {
  type = string
}
variable "cluster_id" {
  type = string
}
variable "permissions" {
  type = list(string)
}
variable "defined_tags" {
  default = null
}