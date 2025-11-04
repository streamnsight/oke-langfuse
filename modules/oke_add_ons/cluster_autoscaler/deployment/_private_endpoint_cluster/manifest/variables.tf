# Copyright (c) 2021, 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

variable "compartment_id" {
  type        = string
  description = "The compartment the node pools the autoscaler can manage are located"
  default     = null
}

variable "region" {
  type        = string
  description = "Region where the autoscaler is deployed"
  default     = null
}

variable "cluster_autoscaler_use_workload_identity" {
  type    = bool
  default = true
}

variable "autoscaler_pool_settings" {
  type = any
}

variable "image" {
  type = string
}

variable "cloud_provider" {
  type    = string
  default = "oci"
}

variable "cluster_autoscaler_log_level_verbosity" {
  type    = number
  default = 4
}

variable "cluster_autoscaler_max_node_provision_time" {
  default     = 25
  description = "Maximum wait time (min) for nodes to provision before failure"
}

variable "cluster_autoscaler_scale_down_delay_after_add" {
  default     = 10
  description = "Minimum delay (min) before scaling a node down after it was provisioned"
}

variable "cluster_autoscaler_scale_down_unneeded_time" {
  default     = 10
  description = "Minimum delay (min) before scaling a node down once it is unneeded"
}

variable "cluster_autoscaler_unremovable_node_recheck_timeout" {
  default     = 5
  description = "Time (min) between checks on status of unremovable"
}
