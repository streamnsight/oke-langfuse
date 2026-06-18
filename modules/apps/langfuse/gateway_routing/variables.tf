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

variable "tls_mode" {
  type    = string
  default = "ip_letsencrypt_http01"

  validation {
    condition     = contains(["ip_letsencrypt_http01", "oci_lb_certificate"], var.tls_mode)
    error_message = "tls_mode must be one of: ip_letsencrypt_http01, oci_lb_certificate."
  }
}

variable "enable_cert_manager_gateway_api" {
  type    = bool
  default = true
}

variable "langfuse_hostname" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "artifact_repo_id" {
  type = string
}

variable "shape_name" {
  type = string
}
