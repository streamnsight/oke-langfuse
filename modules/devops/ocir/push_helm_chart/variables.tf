variable "region" {
  type = string
}

variable "oci_profile" {
  type    = string
  default = "DEFAULT"
}

variable "compartment_id" {
  type = string
}

variable "object_storage_namespace" {
  type = string
}

variable "oss_charts_repo_prefix" {
  type = string
}

variable "chart" {
  type = any
}