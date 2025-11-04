variable "enabled" {
  type    = bool
  default = true
}

variable "cluster_autoscaler_use_workload_identity" {
  type = bool
}

variable "region" {
  type    = string
  default = null
}

variable "compartment_id" {
  type    = string
  default = null
}

variable "kubernetes_version" {
  type = string
}

variable "autoscaler_pool_settings" {
  type = any
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
