## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
variable "enabled" {
  type    = bool
  default = true
}

variable "cluster_id" {
  type = string
}

variable "istio_version" {
  type    = string
  default = null
}

variable "nb_replicas" {
  type    = string
  default = 1
}
