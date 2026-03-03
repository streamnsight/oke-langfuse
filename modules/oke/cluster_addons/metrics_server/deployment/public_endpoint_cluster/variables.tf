## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "enabled" {
  type    = bool
  default = true
}

variable "metrics_server_chart_version" {
  type    = string
  default = "3.11.0"
}

variable "helm_values" {
  type    = any
  default = {}
}
