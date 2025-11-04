## Copyright © 2022-2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  metrics_server_helm_values = {
    "numOfReplicas" = 2
  }
}

# Deployment method for a public or private endpoint cluster when 
# it is an enhanced cluster.
# This method uses the cluster add-on resource for enhanced clusters
module "metrics_server_deployment_with_addon_manager" {
  #TODO set flag for deploy metrics server
  count         = local.cluster_autoscaler_enabled ? (local.use_addon_manager ? 1 : 0) : 0
  source        = "./modules/oke_add_ons/metrics_server/deployment/enhanced_cluster_addon"
  cluster_id    = oci_containerengine_cluster.oci_oke_cluster.id
  nb_replicas   = 2
  addon_version = null # null sets auto-update
  depends_on = [
    data.oci_containerengine_cluster_kube_config.oke,
    oci_containerengine_node_pool.oci_oke_node_pool
  ]
}


# # Deployment method for a public endpoint cluster whether enhanced or not
# # This method uses the kubernetes terraform provider to access the cluster via the public endpoint.
# module "metrics_server_deployment_with_kubernetes_provider" {
#   count                        = local.enable_metrics_server ? (var.is_endpoint_public ? 1 : 0) : 0
#   source                       = "./modules/add-ons/metrics_server/deployment/public_endpoint_cluster"
#   metrics_server_chart_version = var.metrics_server_chart_version
#   helm_values                  = local.metrics_server_helm_values
#   depends_on = [
#     data.oci_containerengine_cluster_kube_config.oke,
#     oci_containerengine_node_pool.oci_oke_node_pool
#   ]
# }


# # Deployment method for a private endpoint cluster when it is not an enhanced cluster
# # This method uses the DevOps service to deploy on a private endpoint cluster

# module "metrics_server_deployment_with_devops" {
#   count                        = local.enable_metrics_server ? (!var.is_endpoint_public ? 1 : 0) : 0
#   source                       = "./modules/add-ons/metrics_server/deployment/private_endpoint_cluster"
#   devops_project_id            = module.devops_setup[0].project_id
#   devops_environment_id        = module.devops_target_cluster_env[0].environment_id
#   region                       = var.region
#   tenancy_ocid                 = var.tenancy_ocid
#   oci_profile                  = var.oci_profile
#   cluster_compartment_id       = var.cluster_compartment_id
#   devops_compartment_id        = var.devops_compartment_id
#   object_storage_namespace     = local.object_storage_namespace
#   oss_images_repo_prefix       = var.oss_images_repo_prefix
#   oss_charts_repo_prefix       = var.oss_charts_repo_prefix
#   push_oss_images              = var.push_oss_images
#   metrics_server_chart_version = "3.11.0"
#   metrics_server_image_version = "v0.6.4"
#   helm_values                  = local.metrics_server_helm_values
#   force_deployment             = var.metrics_server_force_devops_deployment
#   defined_tags                 = var.defined_tags
# }
