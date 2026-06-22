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
    condition = contains([
      "none",
      "ip_letsencrypt_http01",
      "domain_letsencrypt_http01",
      "existing_oci_certificate",
      "import_certificate_pem"
    ], var.tls_mode)
    error_message = "tls_mode must be one of: none, ip_letsencrypt_http01, domain_letsencrypt_http01, existing_oci_certificate, import_certificate_pem."
  }
}

variable "langfuse_certificate_ocid" {
  type    = string
  default = ""
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
