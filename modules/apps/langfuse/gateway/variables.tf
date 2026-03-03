## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "devops_project_id" {
  type = string
}
variable "devops_environment_id" {
  type = string
}
variable "defined_tags" {
  type    = map(string)
  default = {}
}

variable "compartment_id" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "artifact_repo_id" {
  type = string
}