## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable tenancy_ocid {
  type = string 
}

variable "compartment_id" {
  type = string
}

variable "region" {
  type = string
}

variable "deploy_id" {
  type = string
}

variable "secrets_store_csi_provider_helm_chart_version" {
  type = string
  default = "0.4.1"
}

variable "defined_tags" {
  type    = any
  default = null
}

variable "devops_project_id" {
  type = string
}

variable "devops_environment_id" {
  type = string
}

variable "force_deployment" {
  type    = bool
  default = false
}

variable "oci_profile" {
  type    = string
  default = "DEFAULT"
}
