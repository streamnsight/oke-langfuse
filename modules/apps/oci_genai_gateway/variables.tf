variable "compartment_id" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "region" {
  type = string
}

variable "deploy_id" {
  type = string
}

variable "oci_genai_gateway_tag" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "devops_project_id" {
  type = string
}

variable "devops_environment_id" {
  type = string
}
variable "defined_tags" {
  type    = any
  default = {}
}

variable "force_deployment" {
  type    = bool
  default = false
}

variable "builder_details" {
  type = map(any)
}
