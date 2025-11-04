## Copyright © 2022-2024, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# Global
variable "region" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "oci_profile" {
  type    = string
  default = "DEFAULT"
}

# Network
variable "use_existing_vcn" {
  default = false
}

variable "vcn_compartment_id" {
  type = string
}

variable "vcn_cidr" {
  default = "10.0.0.0/16"
}

variable "vcn_id" {
  default = null
}

variable "vcn_tags" {
  default = null
}

variable "is_endpoint_public" {
  default = false
}

variable "kubernetes_endpoint_subnet" {
  default = null
}

# Cluster
variable "cluster_compartment_id" {
  type = string
}

variable "cluster_name" {
  default = "OKE Cluster"
}

variable "is_enhanced_cluster" {
  type    = bool
  default = true
}

variable "kubernetes_version" {
  default = null
  # default to latest version if null
}

variable "node_pool_count" {
  default = 1
}

variable "cluster_tags" {
  default = null
}

variable "pods_cidr" {
  default = "10.1.0.0/16"
}

variable "services_cidr" {
  default = "10.2.0.0/16"
}

# Node Pools
variable "np1_subnet" {
  default = null
}

variable "np1_ha" {
  default = true
}

variable "np1_availability_domain" {
  default = null
}

variable "np1_node_count" {
  default = 3
}

variable "np1_enable_autoscaler" {
  default = true
}

variable "np1_autoscaler_min_nodes" {
  default = 1
}

variable "np1_autoscaler_max_nodes" {
  default = 6
}

variable "np1_node_shape" {
  default = "VM.Standard.E3.Flex"
}

variable "np1_ocpus" {
  default = 4
}

variable "np1_memory_gb" {
  default = 64
}

variable "np1_image_id" {
  default = ""
}

variable "np1_boot_volume_size_in_gbs" {
  default = 50
}

variable "np1_tags" {
  default = null
}

variable "np2_subnet" {
  default = null
}

variable "np2_ha" {
  default = true
}

variable "np2_availability_domain" {
  default = null
}

variable "np2_create_new_subnet" {
  default = false
}

variable "np2_node_count" {
  default = 0
}

variable "np2_enable_autoscaler" {
  default = true
}

variable "np2_autoscaler_min_nodes" {
  default = 0
}

variable "np2_autoscaler_max_nodes" {
  default = 6
}

variable "np2_node_shape" {
  default = null
}

variable "np2_ocpus" {
  default = 4
}

variable "np2_memory_gb" {
  default = 64
}

variable "np2_image_id" {
  default = null
}

variable "np2_boot_volume_size_in_gbs" {
  default = 50
}

variable "np2_tags" {
  default = null
}

variable "np3_subnet" {
  default = null
}

variable "np3_ha" {
  default = true
}

variable "np3_availability_domain" {
  default = null
}

variable "np3_create_new_subnet" {
  default = false
}

variable "np3_node_count" {
  default = 0
}

variable "np3_enable_autoscaler" {
  default = true
}

variable "np3_autoscaler_min_nodes" {
  default = 0
}

variable "np3_autoscaler_max_nodes" {
  default = 6
}

variable "np3_node_shape" {
  default = null
}

variable "np3_ocpus" {
  default = 4
}

variable "np3_memory_gb" {
  default = 64
}

variable "np3_image_id" {
  default = null
}

variable "np3_boot_volume_size_in_gbs" {
  default = 50
}

variable "np3_tags" {
  default = null
}

variable "allow_deploy_public_lb" {
  default = true
}

variable "public_lb_subnet" {
  default = null
}

variable "enable_secret_encryption" {
  default = false
}

variable "secrets_key_id" {
  default = null
}

variable "enable_image_validation" {
  default = false
}

variable "image_validation_key_id" {
  default = null
}

variable "enable_pod_admission_controller" {
  default = null
}

variable "cluster_options_add_ons_is_kubernetes_dashboard_enabled" {
  default = true
}

variable "cluster_options_add_ons_is_tiller_enabled" {
  default = true
}

variable "ssh_public_key" {
  default = null
}

variable "enable_cluster_autoscaler" {
  type    = bool
  default = null
}

# Add-ons
variable "enable_metrics_server" {
  default = true
}

variable "enable_cert_manager" {
  default = true
}

# Apps
variable "enable_flink" {
  default = true
}

variable "enable_monitoring_stack" {
  default = true
}

variable "cert_manager_version" {
  type    = string
  default = "v1.11.0"
}

variable "cert_manager_nb_replicas" {
  type    = number
  default = 2
}

variable "cert_manager_force_devops_deployment" {
  type    = bool
  default = false
}

variable "metrics_server_chart_version" {
  type    = string
  default = "3.11.0"
}

variable "metrics_server_force_devops_deployment" {
  type        = bool
  description = "Force a deployment of the metrics-server via DevOps pipelines on each apply. This can be used to debug deployment."
  default     = false
}


variable "cluster_autoscaler_ocir_region" {
  description = "OCIR Region for the cluster autoscaler image"
  default     = "us-ashburn-1"
}

variable "cluster_autoscaler_use_workload_identity" {
  type        = bool
  description = "Use Workload Identity method for cluster autoscaler permissions."
  default     = false
}

variable "cluster_autoscaler_force_devops_deployment" {
  type        = bool
  description = "Force a deployment of the Cluster Autoscaler via DevOps pipelines on each apply. This can be used to debug deployment."
  default     = false
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

variable "defined_tags" {
  type    = any
  default = null
}

variable "devops_compartment_id" {
  type    = string
  default = null
}

variable "oss_images_repo_prefix" {
  type    = string
  default = "oss_images"
}

variable "oss_charts_repo_prefix" {
  type    = string
  default = "oss_charts"
}

variable "push_oss_images" {
  type = bool
}

variable "object_storage_namespace" {
  type    = string
  default = null
}

variable "create_bastion" {
  type = bool
}

variable "s3_client_id" {
  type      = string
  sensitive = true
}

variable "s3_client_secret" {
  type      = string
  sensitive = true
}

variable "idcs_client_id" {
  type      = string
  sensitive = true
}

variable "idcs_client_secret" {
  type      = string
  sensitive = true
}

variable "idcs_app_id" {
  type = string
}

variable "oci_genai_gateway_tag" {
  type    = string
  default = "581e3cb7150404d80b35f7875f0d28d1510d6de8"
}