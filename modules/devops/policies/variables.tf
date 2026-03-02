## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "devops_compartment_id" {
  type = string
}

variable "vcn_compartment_id" {
  type = string
}

variable "cluster_compartment_id" {
  type = string
}

variable "secrets_store_vault_compartment_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "defined_tags" {
  type    = any
  default = null
}
