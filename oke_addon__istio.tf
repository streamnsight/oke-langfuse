## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

module "istio_deployment_using_addon_manager" {
  count       = (var.use_existing_cluster ? (local.use_addon_manager && !contains(local.existing_addons, "Istio")) : var.is_enhanced_cluster) ? 1 : 0
  source      = "./modules/oke/cluster_addons/istio/deployment/enhanced_cluster_addon"
  cluster_id  = local.target_cluster_id
  nb_replicas = 1
}

module "istio_gateway_crds" {
  source                = "./modules/oke/istio_gateway_crds"
  compartment_id        = var.devops_compartment_id
  cluster_id            = local.target_cluster_id
  devops_project_id     = module.devops_setup.project_id
  devops_environment_id = module.devops_target_cluster_env.environment_id
  subnet_id             = data.oci_containerengine_cluster.target.endpoint_config[0].subnet_id
  depends_on = [
    module.istio_deployment_using_addon_manager
  ]
}
