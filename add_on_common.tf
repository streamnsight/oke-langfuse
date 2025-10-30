## Copyright © 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# defines trigger to enable specific components based on selection
locals {
  enable_cert_manager       = var.enable_cert_manager
  enable_cluster_autoscaler = var.np1_enable_autoscaler || var.np2_enable_autoscaler || var.np3_enable_autoscaler
  enable_metrics_server     = var.enable_metrics_server
}

# Define what deployment method will be used depending on the cluster type and k8s endpoint access
locals {
  any_addon_enabled = local.enable_cert_manager || local.enable_cluster_autoscaler || local.enable_metrics_server
  # enhanced clusters use add-on manager
  use_addon_manager = var.is_enhanced_cluster
  # private endpoint basic clusters use a DevOps pipeline
  use_devops = !var.is_enhanced_cluster && !var.is_endpoint_public && local.any_addon_enabled
  # public endpoint basic clusters use direct deployment with the kubernetes provider
  use_direct = !var.is_enhanced_cluster && var.is_endpoint_public

  object_storage_namespace = var.object_storage_namespace == null ? data.oci_objectstorage_namespace.ns.namespace : var.object_storage_namespace
}

# # Setup the DevOps project when using DevOps
# module "devops_setup" {
#   count          = local.use_devops ? 1 : 0
#   source         = "./modules/devops/project"
#   compartment_id = var.devops_compartment_id
#   project_name   = "${local.cluster_name}-deployments"
#   target_cluster = oci_containerengine_cluster.oci_oke_cluster
#   defined_tags   = var.defined_tags
# }

# # Setup the DevOps project cluster environment when using DevOps
# module "devops_target_cluster_env" {
#   count          = local.use_devops ? 1 : 0
#   source         = "./modules/devops/environment"
#   project_id     = module.devops_setup[0].project_id
#   target_cluster = oci_containerengine_cluster.oci_oke_cluster
#   defined_tags   = var.defined_tags
# }

# # Create policies for the DevOps service to do its work.
# module "devops_policies" {
#   count                  = local.use_devops ? 1 : 0
#   source                 = "./modules/devops/policies"
#   devops_compartment_id  = var.devops_compartment_id
#   vcn_compartment_id     = var.vcn_compartment_id
#   cluster_compartment_id = var.cluster_compartment_id
#   cluster_name           = local.cluster_name_sanitized
#   providers = {
#     oci = oci.home_region
#   }
# }