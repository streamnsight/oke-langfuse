## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "compartment_id" {
  type = string
}

variable "oci_profile" {
  type    = string
  default = "DEFAULT"
}

variable "tenancy_namespace" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "genai_region" {
  type = string
}

variable "deploy_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "builder_instance_private_ip" {
  type = string
}

variable "builder_instance_private_key_secret_ocid" {
  type = string
}

variable "oci_genai_gateway_tag" {
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

variable "defined_tags" {
  type    = any
  default = {}
}

variable "force_deployment" {
  type    = bool
  default = false
}

variable "secrets_store_vault_compartment_id" {
  type = string
}

variable "secrets_store_vault_id" {
  type = string
}

variable "secrets_store_key_id" {
  type = string
}