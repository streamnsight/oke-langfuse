variable "compartment_id" {
  type        = string
  description = "Compartment ID"
}
variable "project_name" {
  type        = string
  description = "DevOps Project Name"
}

variable "target_cluster" {
  type        = any
  description = "The OKE cluster object"
}

variable "defined_tags" {
  type    = any
  default = null
}