## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "compartment_id" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "region" {
  type = string
}

variable "psql_endpoint" {
  type = map(any)
}

# variable "psql_cert" {
#   type      = string
#   sensitive = true
# }

variable "psql_password" {
  type      = string
  sensitive = true
}

variable "psql_ocid" {
  type = string
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

variable "redis_hostname" {
  type = string
}


variable "redis_password" {
  type = string
}

# variable "bastion_session_id" {
#   type = string
# }

# variable "bastion_session_private_key_content" {
#   type = string
# }

variable "cluster_id" {
  type = string
}

variable "deploy_id" {
  type = string
}

variable "langfuse_helm_chart_version" {
  type = string
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
  default = null
}

variable "langfuse_hostname" {
  type = string
}

variable "langfuse_protocol" {
  type    = string
  default = "https"

  validation {
    condition     = contains(["http", "https"], var.langfuse_protocol)
    error_message = "langfuse_protocol must be either http or https."
  }
}

variable "object_storage_bucket" {
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

variable "artifact_repo_id" {
  type = string
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

variable "shape_name" {
  type = string
}
