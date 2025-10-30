# Copyright © 2022, Oracle and/or its affiliates. 
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# https://github.com/jetstack/cert-manager/blob/master/README.md
# https://artifacthub.io/packages/helm/cert-manager/cert-manager

locals {
  cert_manager_helm_values = {
    "installCRDs"            = true
    "webhook.timeoutSeconds" = "30"
    "replicaCount"           = var.cert_manager_nb_replicas
  }
}

module "cert_manager_deployment_using_addon_manager" {
  # count                = local.enable_cert_manager ? (local.use_addon_manager ? 1 : 0) : 0
  source               = "./modules/add-ons/cert-manager/deployment/enhanced_cluster_addon"
  cluster_id           = oci_containerengine_cluster.oci_oke_cluster.id
  cert_manager_version = null # for auto-update
  nb_replicas          = var.cert_manager_nb_replicas
  depends_on = [
    data.oci_containerengine_cluster_kube_config.oke,
    oci_containerengine_cluster.oci_oke_cluster,
    oci_containerengine_node_pool.oci_oke_node_pool,
  ]
}

# module "cert_manager_deployment_using_kubernetes_provider" {
#   count                = local.enable_cert_manager ? (local.use_direct ? 1 : 0) : 0
#   source               = "./modules/add-ons/cert-manager/deployment/public_endpoint_cluster"
#   cert_manager_version = var.cert_manager_version
#   helm_values          = local.cert_manager_helm_values
#   depends_on = [
#     data.oci_containerengine_cluster_kube_config.oke,
#     oci_containerengine_cluster.oci_oke_cluster,
#     oci_containerengine_node_pool.oci_oke_node_pool,
#   ]
# }

# module "cert_manager_deployment_using_devops_pipeline" {
#   count                    = local.enable_cert_manager ? (local.use_devops ? 1 : 0) : 0
#   source                   = "./modules/add-ons/cert-manager/deployment/private_endpoint_deployment"
#   cert_manager_version     = var.cert_manager_version
#   helm_values              = local.cert_manager_helm_values
#   push_oss_images          = var.push_oss_images
#   region                   = local.cluster_region
#   oci_profile              = var.oci_profile
#   devops_project_id        = module.devops_setup[0].project_id
#   devops_environment_id    = module.devops_target_cluster_env[0].environment_id
#   devops_compartment_id    = var.devops_compartment_id
#   object_storage_namespace = local.object_storage_namespace
#   oss_charts_repo_prefix   = var.oss_charts_repo_prefix
#   oss_images_repo_prefix   = var.oss_images_repo_prefix
#   force_deployment         = var.cert_manager_force_devops_deployment
#   defined_tags             = var.defined_tags
#   depends_on = [
#     module.devops_target_cluster_env,
#     oci_containerengine_cluster.oci_oke_cluster,
#     oci_containerengine_node_pool.oci_oke_node_pool,
#   ]
# }

