variable "project_id" {
  type = string
}

variable "target_cluster" {
  type        = any
  description = "The OKE cluster object"
}

variable "defined_tags" {
  type = any
}