variable "region" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "oci_profile" {
  type    = string
  default = "DEFAULT"
}

variable "compartment_id" {
  type = string
}

variable "name_prefix" {
  type    = string
  default = "tests-oke-langfuse"
}

variable "vcn_cidr" {
  type    = string
  default = "10.90.0.0/16"
}

variable "allow_public_api_endpoint" {
  type    = bool
  default = false
}

variable "allow_public_lb" {
  type    = bool
  default = true
}

variable "defined_tags" {
  type    = map(string)
  default = {}
}
