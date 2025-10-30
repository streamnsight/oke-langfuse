variable "devops_compartment_id" {
  type = string
}

variable "vcn_compartment_id" {
  type = string
}

variable "cluster_compartment_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "defined_tags" {
  type    = any
  default = null
}