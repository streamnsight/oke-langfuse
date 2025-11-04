variable "oci_profile" {
  type    = string
  default = "DEFAULT"
}

variable "region" {
  type = string
}

variable "cluster_compartment_id" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "autoscaler_pool_settings" {
  type = any
}

variable "cluster_autoscaler_use_workload_identity" {
  type = bool
}

variable "cluster_autoscaler_log_level_verbosity" {
  type    = number
  default = 4
}

variable "cluster_autoscaler_max_node_provision_time" {
  type = number
}

variable "cluster_autoscaler_scale_down_delay_after_add" {
  type = number
}

variable "cluster_autoscaler_scale_down_unneeded_time" {
  type = number
}

variable "cluster_autoscaler_unremovable_node_recheck_timeout" {
  type = number
}

variable "devops_compartment_id" {
  type = string
}

variable "object_storage_namespace" {
  type = string
}

variable "devops_project_id" {
  type = string
}

variable "devops_environment_id" {
  type = string
}

variable "push_oss_images" {
  type = bool
}

variable "oss_images_repo_prefix" {
  type = string
}

variable "defined_tags" {
  type = any
}

variable "force_deployment" {
  type    = bool
  default = false
}