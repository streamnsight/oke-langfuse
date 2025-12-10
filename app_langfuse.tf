module "langfuse_postgres" {
  source           = "./modules/database/postgres"
  compartment_id   = var.cluster_compartment_id
  subnet_id        = var.use_existing_vcn ? local.node_pools[0]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id
  postgresql_shape = var.postgresql_shape
}

module "langfuse_redis" {
  source         = "./modules/database/redis"
  compartment_id = var.cluster_compartment_id
  display_name   = local.cluster_name_sanitized
  subnet_id      = var.use_existing_vcn ? local.node_pools[0]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id
  node_count     = var.redis_node_count
  node_memory    = var.redis_node_memory
}

locals {
  object_storage_bucket = "langfuse-${local.deploy_id}-traces"
}

resource "oci_objectstorage_bucket" "bucket" {
  #Required
  compartment_id = var.cluster_compartment_id
  name           = local.object_storage_bucket
  namespace      = data.oci_objectstorage_namespace.ns.namespace

  #Optional
  auto_tiering          = "InfrequentAccess"
  object_events_enabled = "false"
  # retention_rules {
  #     display_name = var.retention_rule_display_name
  #     duration {
  #         #Required
  #         time_amount = var.retention_rule_duration_time_amount
  #         time_unit = var.retention_rule_duration_time_unit
  #     }
  #     time_rule_locked = var.retention_rule_time_rule_locked
  # }
  versioning = "Disabled"
}

module "langfuse_load_balancer_no_tls" {
  source          = "./modules/apps/langfuse/load_balancer/no_tls"
  compartment_id  = var.cluster_compartment_id
  builder_details = module.builder_instance.details

  depends_on = [
    null_resource.builder_setup,
    oci_containerengine_node_pool.oci_oke_node_pool
  ]
}

module "langfuse_idcs_app" {
  source             = "./modules/iam/idcs_app"
  identity_domain_id = var.identity_domain_id
  display_name       = local.cluster_name_sanitized
  redirect_url       = "https://${module.langfuse_load_balancer_no_tls.ip_address}/langfuse/api/auth/callback/custom"

  # depends_on = [
  #   module.langfuse_load_balancer_no_tls
  # ]

}

module "langfuse_load_balancer_tls" {
  source            = "./modules/apps/langfuse/load_balancer/tls"
  langfuse_hostname = module.langfuse_load_balancer_no_tls.ip_address
  builder_details   = module.builder_instance.details

  depends_on = [
    null_resource.builder_setup,
    oci_containerengine_node_pool.oci_oke_node_pool,
    module.langfuse_load_balancer_no_tls
  ]
}

# module "langfuse_chart" {
#   source         = "./modules/apps/langfuse/langfuse_chart"
#   compartment_id = var.cluster_compartment_id
#   tenancy_ocid   = var.tenancy_ocid
#   region         = var.region
#   oci_profile    = var.oci_profile
#   cluster_id     = oci_containerengine_cluster.oci_oke_cluster.id
#   builder_details = module.builder.details
#   psql_host             = module.langfuse_postgres.details.endpoint
#   psql_password         = module.langfuse_postgres.details.password
#   psql_cert             = module.langfuse_postgres.details.cert
#   s3_client_id          = var.langfuse_s3_access_key
#   s3_client_secret      = var.langfuse_s3_secret_key
#   idcs_client_id        = module.langfuse_idcs_app.details.client_id
#   idcs_client_secret    = module.langfuse_idcs_app.details.client_secret
#   idcs_app_id           = module.langfuse_idcs_app.details.app_id
#   redis_hostname        = module.langfuse_redis.details.hostname
#   redis_password = module.langfuse_redis.details.password
#   devops_project_id     = module.devops_setup.project_id
#   devops_environment_id = module.devops_target_cluster_env.environment_id
#   object_storage_bucket = local.object_storage_bucket
#   deploy_id             = local.deploy_id
#   langfuse_helm_chart_version = var.langfuse_helm_chart_version
#   langfuse_hostname = local.langfuse_hostname


#   depends_on = [
#     module.langfuse_idcs_app
#     # oci_containerengine_node_pool.oci_oke_node_pool,
#     # # local_file.kubeconfig,
#     # # oci_bastion_session.installer_session
#     # null_resource.builder_setup,
#     # data.oci_load_balancer_load_balancers.load_balancers,
#     # null_resource.create_langfuse_lb_tls
#   ]
# }
