# Copyright (c) 2021, 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
variable "enabled" {
  type    = bool
  default = true
}

variable "cluster_id" {
  type = string
}

variable "cert_manager_version" {
  type    = string
  default = null
}

variable "nb_replicas" {
  type    = string
  default = 1
}

variable "compartment_id" {
  type = string
}

variable "load_balancers_subnet_id" {
  type = string
}