## Install Langfuse dependencies
# Postgres
module "langfuse_postgres" {
  source           = "./modules/database/postgres"
  compartment_id   = var.cluster_compartment_id
  subnet_id        = var.use_existing_vcn ? local.node_pools[0]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id
  postgresql_shape = var.postgresql_shape
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

##  Create a load balancer via Ingress in Kubernetes
# Ingress allows automation of TLS certs creation for the LB using let's encrypt
# as of 12-09-2025 IP certs are only suported in acme-staging, but is supposed to be available in acme-prod
# shortly
# Deploys an Ingress LB without TLS first, so we can get the IP
# TODO: look at using native ingress controller as nginx-ingress is being deprecated in March 2026
# https://cert-manager.io/announcements/2025/11/26/ingress-nginx-eol-and-gateway-api/

# TODO: override LB settings to take full advantage of OCI LB capabilities

module "langfuse_load_balancer_no_tls" {
  source          = "./modules/apps/langfuse/load_balancer/no_tls"
  compartment_id  = var.cluster_compartment_id
  builder_details = module.builder_instance.details
  cluster_id = oci_containerengine_cluster.oci_oke_cluster.id

  depends_on = [
    null_resource.builder_setup,
    oci_containerengine_node_pool.oci_oke_node_pool
  ]
}

# Patch the created Load Balancer with IP based TLS cert
# IP is needed to create the IP cert, so it needs to be patchd after deployment
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

# Create the IDCS app with the proper redirect URL
module "langfuse_idcs_app" {
  count = var.create_idcs_app ? 1 : 0
  source             = "./modules/iam/idcs_app"
  identity_domain_id = var.identity_domain_id
  display_name       = local.cluster_name_sanitized
  redirect_url       = "https://${module.langfuse_load_balancer_no_tls.ip_address}/langfuse/api/auth/callback/custom"
}


locals {
    idcs_app_id                 = var.create_idcs_app ? module.langfuse_idcs_app[0].details.app_id : var.idcs_app_id
  idcs_client_id              = var.create_idcs_app ? module.langfuse_idcs_app[0].details.client_id : var.idcs_client_id
  idcs_client_secret          = var.create_idcs_app ? module.langfuse_idcs_app[0].details.client_secret : var.idcs_client_secret
  idcs_domain_url             = var.create_idcs_app ? module.langfuse_idcs_app[0].details.domain_url : var.idcs_domain_url

}

# Create the Langfuse secrets, patch and build the Langfuse app container image and deploy the helm chart
# The chart is deployed via DevOps pipeline, although secrets are deployed via remote-exec command to avoid storing credentials
# in pipeline paramters
# TODO, see how to use https://github.com/oracle/oci-secrets-store-csi-driver-provider to provision the secrets from vault
module "langfuse_chart" {
  source                      = "./modules/apps/langfuse/langfuse_chart"
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
  langfuse_hostname           = module.langfuse_load_balancer_no_tls.ip_address


  depends_on = [
    module.langfuse_idcs_app,
    module.langfuse_load_balancer_tls,
    module.langfuse_postgres,
    module.langfuse_redis,
    oci_objectstorage_bucket.langfuse_bucket
  ]
}

output "langfuse_url" {
  value = "https://${module.langfuse_load_balancer_no_tls.ip_address}/langfuse"
}