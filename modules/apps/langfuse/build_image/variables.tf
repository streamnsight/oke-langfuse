## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "compartment_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "devops_project_id" {
  type = string
}

variable "devops_environment_id" {
  type = string
}

variable "artifact_repo_id" {
  type = string
}

variable "builder_instance_private_ip" {
  type = string
}

variable "builder_instance_private_key_secret_ocid" {
  type = string
}

variable "deploy_id" {
  type = string
}

variable "ocir_namespace" {
  type = string
}
