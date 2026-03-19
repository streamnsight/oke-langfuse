variable "region" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "cluster_compartment_id" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "tests-basic-cluster"
}

variable "kubernetes_version" {
  type = string
}

variable "pods_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.101.0.0/16"
}

variable "create_bastion" {
  type    = bool
  default = true
}

variable "defined_tags" {
  type    = map(string)
  default = {}
}
