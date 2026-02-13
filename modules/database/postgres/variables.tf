## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "compartment_id" {
  type = string
}

variable "display_name" {
  type = string
}

variable "db_version" {
  type    = string
  default = "16"
}

variable "memory_gb" {
  type    = string
  default = "64"
}

variable "ocpus" {
  type    = string
  default = 2
}

variable "postgresql_shape" {
  type    = string
}

variable "subnet_id" {
  type = string
}

variable "availability_domains" {
  type = list(any)
}
