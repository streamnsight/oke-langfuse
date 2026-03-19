## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  istio_needs_install = var.use_existing_cluster ? (contains(local.existing_addons, "Istio") ? 0 : 1) : 1
}

module "istio_deployment_using_addon_manager" {
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
  subnet_id             = local.workload_subnet_id
  depends_on = [
    module.istio_deployment_using_addon_manager
  ]
}
