variable "enabled" {
  type    = bool
  default = true
}

variable "region" {
  type = string
}

variable "oci_profile" {
  type    = string
  default = "DEFAULT"
}

variable "helm_values" {
  type    = any
  default = {}
}

variable "cert_manager_version" {
  type    = string
  default = "v1.11.0"
}

variable "push_oss_images" {
  type    = bool
  default = true
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