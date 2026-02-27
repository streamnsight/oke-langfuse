## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "compartment_id" {
  type = string
}

variable "vault_id" {
  type = string
}

variable "key_id" {
  type = string
}

variable "psql_endpoint" {
  type = map(any)
}

variable "psql_cert" {
  type      = string
  sensitive = true
}

variable "psql_password" {
  type      = string
  sensitive = true
}

variable "s3_client_id" {
  type      = string
  sensitive = true
}

variable "s3_client_secret" {
  type      = string
  sensitive = true
}

variable "idcs_app_id" {
  type = string
}

variable "idcs_client_id" {
  type      = string
  sensitive = true
}

variable "idcs_client_secret" {
  type      = string
  sensitive = true
}

variable "idcs_domain_url" {
  type = string
}

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

variable "subnet_id" {
  type = string
}