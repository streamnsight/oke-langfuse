## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "compartment_id" {
  type = string
}

variable "compute_shape" {
  type = string
}

variable "display_name" {
  type    = string
  default = "builder"
}

variable "availability_domain" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "metadata" {
  type = map(any)
}

variable "ssh_authorized_keys" {
  type = string
}

variable "assign_public_ip" {
  type    = bool
  default = false
}

variable "ocpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 24
}

variable "image_id" {
  type = string
}

variable "boot_volume_gb" {
  type    = number
  default = 100
}

variable "policies" {
  type = list(string)
  default = [
    "manage instance-family",
  ]
}
