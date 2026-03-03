## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# module "secrets_store_csi_helm_chart_deployment" {
#   # count                = local.enable_cert_manager ? (local.use_addon_manager ? 1 : 0) : 0
#   source      = "./modules/oke/secrets_store/csi_driver_provider"
#   tenancy_ocid = var.tenancy_ocid
#   compartment_id = local.devops_compartment_id
#   region = var.region
#   oci_profile             = var.oci_profile
#   devops_environment_id = module.devops_target_cluster_env.environment_id
#   devops_project_id = module.devops_setup.project_id
#   deploy_id = local.deploy_id
#   depends_on = [
#     oci_containerengine_cluster.oci_oke_cluster,
#     oci_containerengine_node_pool.oci_oke_node_pool,
#   ]
# }

