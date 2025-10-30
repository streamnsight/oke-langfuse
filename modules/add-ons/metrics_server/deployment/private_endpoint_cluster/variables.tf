variable "tenancy_ocid" {
  type = string
}

variable "oci_profile" {
  type    = string
  default = "DEFAULT"
}

variable "region" {
  type = string
}

variable "cluster_compartment_id" {
  type = string
}

variable "devops_compartment_id" {
  type = string
}

variable "object_storage_namespace" {
  type = string
}

variable "devops_project_id" {
  type = string
}

variable "devops_environment_id" {
  type = string
}

variable "push_oss_images" {
  type = bool
}

variable "metrics_server_chart_version" {
  type    = string
  default = "3.11.0"
}

variable "metrics_server_image_version" {
  type    = string
  default = "v0.6.4"
}

variable "helm_values" {
  type    = any
  default = {}
}

variable "oss_images_repo_prefix" {
  type = string
}

variable "oss_charts_repo_prefix" {
  type = string
}

variable "defined_tags" {
  type = any
}

variable "force_deployment" {
  type    = bool
  default = false
}