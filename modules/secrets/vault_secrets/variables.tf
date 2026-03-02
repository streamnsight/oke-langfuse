## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "profile" {
  type    = string
  default = "DEFAULT"
}

variable "compartment_id" {
  type = string
}

variable "vault_id" {
  type = string
}

variable "key_id" {
  type = string
}

variable "secrets" {
  type = list(object({
    name     = string
    required = optional(bool, true)
    value    = optional(string)
    generator = optional(object({
      type  = string
      bytes = number
    }))
  }))

  validation {
    condition = alltrue([
      for secret in var.secrets : (
        (secret.value != null ? 1 : 0) + (secret.generator != null ? 1 : 0)
      ) == 1
    ])
    error_message = "Each secret must define exactly one of 'value' or 'generator'."
  }

  validation {
    condition = alltrue([
      for secret in var.secrets : (
        try(secret.generator.type, null) == null
        || contains(["openssl_hex"], try(secret.generator.type, ""))
      )
    ])
    error_message = "Supported generator types are: openssl_hex."
  }

  validation {
    condition = alltrue([
      for secret in var.secrets : (
        try(secret.generator.type, null) == null
        || try(secret.generator.bytes, 0) > 0
      )
    ])
    error_message = "Generator bytes must be greater than 0 when a generator is provided."
  }
}
