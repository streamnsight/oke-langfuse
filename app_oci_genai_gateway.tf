module "oci_genai_gateway" {
  source                              = "./modules/apps/oci_genai_gateway"
  compartment_id                      = var.cluster_compartment_id
  tenancy_ocid                        = var.tenancy_ocid
  region                              = var.region
  cluster_id                          = oci_containerengine_cluster.oci_oke_cluster.id
  bastion_session_id                  = oci_bastion_session.installer_session[0].id
  bastion_session_private_key_content = tls_private_key.bastion_session_public_private_key_pair.private_key_openssh
  oci_genai_gateway_tag               = var.oci_genai_gateway_tag
  devops_project_id = module.devops_setup.project_id
  devops_environment_id = module.devops_target_cluster_env.environment_id
  depends_on = [
    oci_containerengine_node_pool.oci_oke_node_pool,
    # oci_bastion_session.installer_session
  ]
}