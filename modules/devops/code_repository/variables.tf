## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "defined_tags" {
  type    = any
  default = {}
}

variable "description" {
  type = string
}
