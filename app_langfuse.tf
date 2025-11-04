
module "langfuse" {
  source                              = "./modules/apps/langfuse"
  compartment_id                      = var.cluster_compartment_id
  tenancy_ocid                        = var.tenancy_ocid
  region                              = var.region
  cluster_id                          = oci_containerengine_cluster.oci_oke_cluster.id
  bastion_session_id                  = oci_bastion_session.installer_session[0].id
  bastion_session_private_key_content = tls_private_key.bastion_session_public_private_key_pair.private_key_openssh
  psql_host                           = data.oci_psql_db_system_connection_detail.psql_connection_detail.primary_db_endpoint[0].fqdn
  psql_cert                           = data.oci_psql_db_system_connection_detail.psql_connection_detail.ca_certificate
  psql_password                       = random_string.postgres_password.result
  s3_client_id                        = var.s3_client_id
  s3_client_secret                    = var.s3_client_secret
  idcs_client_id                      = var.idcs_client_id
  idcs_client_secret                  = var.idcs_client_secret
  idcs_app_id                         = var.idcs_app_id
  redis_hostname                      = oci_redis_redis_cluster.redis.primary_fqdn

  depends_on = [
    oci_containerengine_node_pool.oci_oke_node_pool,
    local_file.kubeconfig,
    oci_bastion_session.installer_session
  ]

}