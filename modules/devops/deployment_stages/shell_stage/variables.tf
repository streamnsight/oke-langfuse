## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "devops_project_id" {
  type = string
}
variable "devops_environment_id" {
  type = string
}

variable "manifest_repository_id" {
  type    = string
  default = null
}

variable "stage_name" {
  type = string
}

variable "command_spec_content" {
  type = string
}

variable "deploy_pipeline_parameters" {
  type = any
}
variable "defined_tags" {
  type    = map(string)
  default = {}
}

variable "compartment_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "timeout" {
  type    = number
  default = 600
}

variable "shape_name" {
  type = string
}
