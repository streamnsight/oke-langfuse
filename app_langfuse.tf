## Copyright © 2022-2026, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl
## Install Langfuse dependencies
# Postgres
module "langfuse_postgres" {
  source               = "./modules/database/postgres"
  compartment_id       = var.cluster_compartment_id
  subnet_id            = var.use_existing_vcn ? local.node_pools[0]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id
  postgresql_shape     = var.postgresql_shape
  availability_domains = local.ADs
}

# Redis / OCI Cache
module "langfuse_redis" {
  source         = "./modules/database/redis"
  compartment_id = var.cluster_compartment_id
  display_name   = local.cluster_name_sanitized
  subnet_id      = var.use_existing_vcn ? local.node_pools[0]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id
  node_count     = var.redis_node_count
  node_memory    = var.redis_node_memory
}

# Object storage bucket
locals {
  object_storage_bucket = "langfuse-${local.deploy_id}-traces"
}

resource "oci_objectstorage_bucket" "langfuse_bucket" {
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

# Create the IDCS app with the proper redirect URL
module "langfuse_idcs_app" {
  count              = var.create_idcs_app ? 1 : 0
  source             = "./modules/iam/idcs_app"
  identity_domain_id = var.identity_domain_id
  display_name       = local.cluster_name_sanitized
  redirect_url       = "https://${module.nginx_ingress_controller.ip_address}/langfuse/api/auth/callback/custom"
}


locals {
  idcs_app_id        = var.create_idcs_app ? module.langfuse_idcs_app[0].details.app_id : var.idcs_app_id
  idcs_client_id     = var.create_idcs_app ? module.langfuse_idcs_app[0].details.client_id : var.idcs_client_id
  idcs_client_secret = var.create_idcs_app ? module.langfuse_idcs_app[0].details.client_secret : var.idcs_client_secret
  idcs_domain_url    = var.create_idcs_app ? module.langfuse_idcs_app[0].details.domain_url : var.idcs_domain_url

}

# Build Langfuse patched container image
module "build_langfuse_image" {
  source                      = "./modules/apps/langfuse/build_image"
  builder_details             = module.builder_instance.details

  depends_on = [ 
    module.builder_instance,
    null_resource.builder_setup
  ]
}


# Create the Langfuse secrets and deploy the helm chart
# The chart is deployed via DevOps pipeline, although secrets are deployed via remote-exec command to avoid storing credentials
# in pipeline paramters
# TODO, see how to use https://github.com/oracle/oci-secrets-store-csi-driver-provider to provision the secrets from vault
module "langfuse_chart" {
  source                      = "./modules/apps/langfuse/helm_chart"
  compartment_id              = var.cluster_compartment_id
  tenancy_ocid                = var.tenancy_ocid
  region                      = var.region
  oci_profile                 = var.oci_profile
  cluster_id                  = oci_containerengine_cluster.oci_oke_cluster.id
  builder_details             = module.builder_instance.details
  psql_endpoint               = module.langfuse_postgres.details.endpoint
  psql_password               = module.langfuse_postgres.details.password
  psql_cert                   = module.langfuse_postgres.details.cert
  s3_client_id                = var.langfuse_s3_access_key
  s3_client_secret            = var.langfuse_s3_secret_key
  idcs_app_id                 = local.idcs_app_id
  idcs_client_id              = local.idcs_client_id
  idcs_client_secret          = local.idcs_client_secret
  idcs_domain_url             = local.idcs_domain_url
  redis_hostname              = module.langfuse_redis.details.hostname
  redis_password              = module.langfuse_redis.details.password
  devops_project_id           = module.devops_setup.project_id
  devops_environment_id       = module.devops_target_cluster_env.environment_id
  object_storage_bucket       = local.object_storage_bucket
  deploy_id                   = local.deploy_id
  langfuse_helm_chart_version = var.langfuse_helm_chart_version
  langfuse_hostname           = module.nginx_ingress_controller.ip_address


  depends_on = [
    module.langfuse_idcs_app,
    module.nginx_ingress_controller,
    module.langfuse_postgres,
    module.langfuse_redis,
    oci_objectstorage_bucket.langfuse_bucket,
    module.build_langfuse_image,
    module.cert_manager_deployment_using_addon_manager
  ]
}

output "langfuse_url" {
  value = "https://${module.nginx_ingress_controller.ip_address}/langfuse"
}

# Ingress allows automation of TLS certs creation for the LB using let's encrypt
module "langfuse_ingress_tls" {
  source            = "./modules/apps/langfuse/ingress_tls"
  langfuse_hostname = module.nginx_ingress_controller.ip_address
  builder_details   = module.builder_instance.details
  devops_project_id = module.devops_setup.project_id
  devops_environment_id = module.devops_target_cluster_env.environment_id

  depends_on = [
    null_resource.builder_setup,
    oci_containerengine_node_pool.oci_oke_node_pool,
    module.cert_manager_deployment_using_addon_manager,
    module.nginx_ingress_controller,
    module.langfuse_chart
  ]
}
