## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# Global
variable "region" {
  type = string
}

variable "tenancy_ocid" {
  type = string

  validation {
    condition     = can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.tenancy_ocid))
    error_message = "tenancy_ocid must be a valid OCID."
  }
}

variable "oci_profile" {
  type    = string
  default = "DEFAULT"
}

# Network
variable "use_existing_vcn" {
  default = false
}

variable "use_existing_cluster" {
  type    = bool
  default = false
}

variable "cluster_ocid" {
  type    = string
  default = null

  validation {
    condition     = var.cluster_ocid == null || (var.cluster_ocid != "" && can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.cluster_ocid)))
    error_message = "cluster_ocid must be null or a valid non-empty OCID string."
  }
}

variable "enable_existing_cluster_cloud_init_preflight" {
  type    = bool
  default = false
}

variable "existing_cluster_cloud_init_required_markers" {
  type = list(string)
  default = [
    "/usr/local/bin/docker_login.sh",
    "/usr/local/bin/docker-credential-helper-init.sh",
    "*/20 * * * * /bin/bash -lc",
  ]
}

variable "vcn_compartment_id" {
  type    = string
  default = null

  validation {
    condition     = var.vcn_compartment_id == null || can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.vcn_compartment_id))
    error_message = "vcn_compartment_id must be null or a valid OCID."
  }
}

variable "vcn_cidr" {
  default = "10.0.0.0/16"
}

variable "vcn_id" {
  default = null

  validation {
    condition     = var.vcn_id == null || can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.vcn_id))
    error_message = "vcn_id must be null or a valid OCID."
  }
}

variable "vcn_tags" {
  default = null
}

variable "is_endpoint_public" {
  default = false
}

variable "kubernetes_endpoint_subnet" {
  default = null

  validation {
    condition     = var.kubernetes_endpoint_subnet == null || can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.kubernetes_endpoint_subnet))
    error_message = "kubernetes_endpoint_subnet must be null or a valid OCID."
  }
}

# Cluster
variable "cluster_compartment_id" {
  type = string

  validation {
    condition     = can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.cluster_compartment_id))
    error_message = "cluster_compartment_id must be a valid OCID."
  }
}

variable "cluster_name" {
  default = "Langfuse Cluster"
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

  validation {
    condition     = var.np1_subnet == null || can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.np1_subnet))
    error_message = "np1_subnet must be null or a valid OCID."
  }
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
  default = "VM.Standard.E4.Flex"
}

variable "np1_ocpus" {
  default = 4
}

variable "np1_memory_gb" {
  default = 64
}

variable "np1_operating_system" {
  type    = string
  default = "Oracle Linux"
}

variable "np1_operating_system_version" {
  type    = string
  default = "8"
}

variable "np1_image_override" {
  type    = bool
  default = false
}

variable "np1_image_id" {
  type    = string
  default = null
}

variable "np1_boot_volume_size_in_gbs" {
  default = 500
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

variable "np2_operating_system" {
  type    = string
  default = "Oracle Linux"
}

variable "np2_operating_system_version" {
  type    = string
  default = "8"
}

variable "np2_image_override" {
  type    = bool
  default = false
}

variable "np2_image_id" {
  type    = string
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

variable "np3_operating_system" {
  type    = string
  default = "Oracle Linux"
}

variable "np3_operating_system_version" {
  type    = string
  default = "8"
}

variable "np3_image_override" {
  type    = bool
  default = false
}

variable "np3_image_id" {
  type    = string
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

  validation {
    condition     = var.public_lb_subnet == null || can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.public_lb_subnet))
    error_message = "public_lb_subnet must be null or a valid OCID."
  }
}

variable "langfuse_use_custom_domain" {
  type        = bool
  default     = false
  description = "Use a custom FQDN for Langfuse instead of the load balancer IP address."
}

variable "langfuse_custom_domain_fqdn" {
  type        = string
  default     = null
  description = "Custom fully qualified domain name for Langfuse. Do not include a scheme or path."
}

variable "langfuse_tls_mode" {
  type        = string
  default     = null
  description = "TLS mode for the Langfuse endpoint. Null preserves legacy behavior. DNS01 is reserved for a future release and is not currently accepted."

  validation {
    condition = var.langfuse_tls_mode == null || contains([
      "none",
      "ip_letsencrypt_http01",
      "domain_letsencrypt_http01",
      "existing_oci_certificate",
      "import_certificate_pem"
    ], var.langfuse_tls_mode)
    error_message = "langfuse_tls_mode must be null or one of: none, ip_letsencrypt_http01, domain_letsencrypt_http01, existing_oci_certificate, import_certificate_pem."
  }
}

variable "langfuse_certificate_source" {
  type        = string
  default     = "existing_oci_certificate"
  description = "Source for the custom-domain TLS certificate. Use existing_oci_certificate to provide an OCI certificate OCID, or import_certificate_pem to let the stack import PEM material into OCI Certificates Service."

  validation {
    condition     = contains(["existing_oci_certificate", "import_certificate_pem"], var.langfuse_certificate_source)
    error_message = "langfuse_certificate_source must be one of: existing_oci_certificate, import_certificate_pem."
  }
}

variable "langfuse_certificate_ocid" {
  type        = string
  default     = null
  description = "OCI Certificates Service leaf certificate OCID to use for the Langfuse custom domain."

  validation {
    condition     = var.langfuse_certificate_ocid == null || can(regex("^ocid1\\.certificate\\.[^.]+\\..+$", var.langfuse_certificate_ocid))
    error_message = "langfuse_certificate_ocid must be null or a valid OCI Certificates Service certificate OCID."
  }
}

variable "langfuse_certificate_pem" {
  type        = string
  default     = null
  sensitive   = true
  description = "PEM-encoded leaf certificate to import into OCI Certificates Service for the Langfuse custom domain."
}

variable "langfuse_private_key_pem" {
  type        = string
  default     = null
  sensitive   = true
  description = "PEM-encoded private key matching langfuse_certificate_pem. This may be stored in Terraform state when using import_certificate_pem."
}

variable "langfuse_certificate_chain_pem" {
  type        = string
  default     = null
  sensitive   = true
  description = "PEM-encoded intermediate certificate chain for langfuse_certificate_pem."
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

variable "cert_manager_version" {
  type    = string
  default = "v1.19.2"
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

  validation {
    condition     = var.devops_compartment_id == null || can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.devops_compartment_id))
    error_message = "devops_compartment_id must be null or a valid OCID."
  }
}

# variable "oss_images_repo_prefix" {
#   type    = string
#   default = "oss_images"
# }

# variable "oss_charts_repo_prefix" {
#   type    = string
#   default = "oss_charts"
# }

# variable "push_oss_images" {
#   type = bool
# }

variable "object_storage_namespace" {
  type    = string
  default = null
}

variable "create_bastion" {
  type    = bool
  default = true
}

variable "langfuse_s3_access_key" {
  type      = string
  sensitive = true
}

variable "langfuse_s3_secret_key" {
  type      = string
  sensitive = true
}


variable "oci_genai_gateway_tag" {
  type    = string
  default = "581e3cb7150404d80b35f7875f0d28d1510d6de8"
}

variable "oci_genai_region" {
  type    = string
  default = "us-chicago-1"
}

variable "postgresql_shape" {
  type    = string
  default = "PostgreSQL.VM.Standard.E5.Flex"
}

variable "redis_node_count" {
  type    = string
  default = "1"
}

variable "redis_node_memory" {
  type    = string
  default = "16"
}

variable "langfuse_helm_chart_version" {
  type    = string
  default = "1.5.27"
}

variable "identity_domain_id" {
  type    = string
  default = null
}

variable "current_user_ocid" {
  type    = string
  default = null

  validation {
    condition     = var.current_user_ocid == null || can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.current_user_ocid))
    error_message = "current_user_ocid must be null or a valid OCID."
  }
}

variable "enable_oci_genai_gateway" {
  type    = bool
  default = true
}

variable "create_idcs_app" {
  type    = bool
  default = true
}

variable "assign_current_user_to_idcs_app" {
  type    = bool
  default = true
}

variable "idcs_app_id" {
  type    = string
  default = null
}

variable "idcs_domain_url" {
  type    = string
  default = null
}

variable "idcs_client_id" {
  type      = string
  default   = null
  sensitive = true
}

variable "idcs_client_secret" {
  type      = string
  default   = null
  sensitive = true
}

variable "use_network_source" {
  type    = bool
  default = true
}

## Secret storage
variable "secrets_store_vault_compartment_id" {
  type = string

  validation {
    condition     = can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.secrets_store_vault_compartment_id))
    error_message = "secrets_store_vault_compartment_id must be a valid OCID."
  }
}

variable "secrets_store_vault_id" {
  type = string

  validation {
    condition     = can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.secrets_store_vault_id))
    error_message = "secrets_store_vault_id must be a valid OCID."
  }
}

variable "secrets_store_key_id" {
  type = string

  validation {
    condition     = can(regex("^ocid1\\.[^.]+\\.[^.]+\\..+$", var.secrets_store_key_id))
    error_message = "secrets_store_key_id must be a valid OCID."
  }
}

variable "test_mode" {
  type        = bool
  default     = false
  description = "Enable additional non-sensitive outputs for local test tooling."
}
