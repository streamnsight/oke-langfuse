## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

## Install Langfuse dependencies
# Postgres
module "langfuse_postgres" {
  source               = "./modules/database/postgres"
  compartment_id       = local.effective_cluster_compartment_id
  subnet_id            = local.workload_subnet_id
  postgresql_shape     = var.postgresql_shape
  display_name         = "langfuse-${local.deploy_id}"
  availability_domains = local.ADs
}

# Redis / OCI Cache
module "langfuse_redis" {
  source         = "./modules/database/redis"
  compartment_id = local.effective_cluster_compartment_id
  display_name   = local.cluster_name_sanitized
  subnet_id      = local.workload_subnet_id
  node_count     = var.redis_node_count
  node_memory    = var.redis_node_memory
}

# Object storage bucket
locals {
  object_storage_bucket = "langfuse-${local.deploy_id}-traces"
}

resource "oci_objectstorage_bucket" "langfuse_bucket" {
  #Required
  compartment_id = local.effective_cluster_compartment_id
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
  redirect_url       = "https://${local.langfuse_url}/langfuse/api/auth/callback/custom"
}


locals {
  idcs_app_id                     = var.create_idcs_app ? module.langfuse_idcs_app[0].details.app_id : var.idcs_app_id
  idcs_client_id                  = var.create_idcs_app ? module.langfuse_idcs_app[0].details.client_id : var.idcs_client_id
  idcs_client_secret              = var.create_idcs_app ? module.langfuse_idcs_app[0].details.client_secret : var.idcs_client_secret
  idcs_domain_url                 = var.create_idcs_app ? module.langfuse_idcs_app[0].details.domain_url : var.idcs_domain_url
  current_user_assignment_enabled = var.create_idcs_app && var.assign_current_user_to_idcs_app && var.current_user_ocid != null && var.current_user_ocid != ""
  current_user_assignment_count   = local.current_user_assignment_enabled ? 1 : 0
}

data "oci_identity_domains_users" "langfuse_current_user" {
  count = local.current_user_assignment_count

  idcs_endpoint = local.idcs_domain_url
  user_count    = 1
  user_filter   = format("ocid eq \"%s\"", var.current_user_ocid)
}

check "langfuse_current_user_identity_domain_user" {
  assert {
    condition     = !local.current_user_assignment_enabled || length(data.oci_identity_domains_users.langfuse_current_user[0].users) == 1
    error_message = "Expected exactly one identity domain user matching current_user_ocid before auto-assigning the current user to the IDCS app."
  }
}

resource "oci_identity_domains_grant" "langfuse_current_user_assignment" {
  count = local.current_user_assignment_count

  grant_mechanism = "ADMINISTRATOR_TO_USER"
  idcs_endpoint   = local.idcs_domain_url
  schemas         = ["urn:ietf:params:scim:schemas:oracle:idcs:Grant"]

  app {
    value = local.idcs_app_id
  }

  grantee {
    type  = "User"
    value = data.oci_identity_domains_users.langfuse_current_user[0].users[0].id
  }
}

# Build Langfuse patched container image
module "build_langfuse_image" {
  source                                   = "./modules/apps/langfuse/build_image"
  compartment_id                           = var.devops_compartment_id
  oci_profile                              = var.oci_profile
  devops_project_id                        = module.devops_setup.project_id
  devops_environment_id                    = module.devops_target_cluster_env.environment_id
  artifact_repo_id                         = local.artifact_repo_id
  subnet_id                                = local.workload_subnet_id
  builder_instance_private_ip              = module.builder_instance.details.private_ip
  builder_instance_private_key_secret_ocid = data.external.builder_ssh_key_to_vault.result.private_key_secret_ocid
  deploy_id                                = local.deploy_id
  tenancy_namespace                        = data.oci_objectstorage_namespace.ns.namespace
  shape_name                               = local.ci_shape_selected

  depends_on = [
    module.builder_instance,
    module.builder_setup_shell_stage
  ]
}

# deploy the load balancer
module "langfuse_gateway" {
  source                = "./modules/apps/langfuse/gateway"
  compartment_id        = local.effective_cluster_compartment_id
  cluster_id            = local.target_cluster_id
  subnet_id             = local.workload_subnet_id
  devops_project_id     = module.devops_setup.project_id
  devops_environment_id = module.devops_target_cluster_env.environment_id
  artifact_repo_id      = oci_artifacts_repository.artifact_repository.id
  shape_name            = local.ci_shape_selected
  depends_on = [
    module.istio_deployment_using_addon_manager,
    module.istio_gateway_crds,
    oci_containerengine_node_pool.oci_oke_node_pool
  ]
}

# locals {
#   secret_store_csi_provider_permissions = [
#     "use secret-family"
#   ]
# }

# # define policies statements to use workload identity
# module "langfuse_secret_store_csi_provider_workload_identity_policy" {
#   source               = "./modules/iam/workload_identity"
#   compartment_id       = var.secrets_store_vault_compartment_id
#   workload_name        = "oci-secrets-store-csi-driver-provider"
#   service_account_name = "langfuse-sa"
#   namespace            = "kube-system"
#   permissions          = local.secret_store_csi_provider_permissions
#   defined_tags         = var.defined_tags
#   cluster_id           = oci_containerengine_cluster.oci_oke_cluster.id
#   providers = {
#     oci = oci.home_region
#   }
# }

# module "langfuse_create_secrets_in_vault" {
#   source = "./modules/apps/langfuse/create_secrets_in_vault"
#   compartment_id              = var.cluster_compartment_id
#   # tenancy_ocid                = var.tenancy_ocid
#   # region                      = var.region
#   # oci_profile                 = var.oci_profile
#   vault_id = var.secrets_store_vault_id
#   key_id = var.secrets_store_key_id
#   subnet_id             = oci_containerengine_cluster.oci_oke_cluster.endpoint_config[0].subnet_id
#   psql_endpoint               = module.langfuse_postgres.details.endpoint
#   psql_password               = module.langfuse_postgres.details.password
#   psql_cert                   = module.langfuse_postgres.details.cert
#   s3_client_id                = var.langfuse_s3_access_key
#   s3_client_secret            = var.langfuse_s3_secret_key
#   idcs_app_id                 = local.idcs_app_id
#   idcs_client_id              = local.idcs_client_id
#   idcs_client_secret          = local.idcs_client_secret
#   idcs_domain_url             = local.idcs_domain_url
#   # redis_hostname              = module.langfuse_redis.details.hostname
#   # redis_password              = module.langfuse_redis.details.password
#   devops_project_id           = module.devops_setup.project_id
#   devops_environment_id       = module.devops_target_cluster_env.environment_id
# }

# module "langfuse_secret_provider_class_deployment" {
#   source = "./modules/apps/langfuse/secret_provider_class"
#   compartment_id        = var.cluster_compartment_id
#   cluster_id            = oci_containerengine_cluster.oci_oke_cluster.id
#   vault_id             = var.secrets_store_vault_id
#   devops_project_id     = module.devops_setup.project_id
#   devops_environment_id = module.devops_target_cluster_env.environment_id
#   depends_on = [
#   ]
# }

# Create the Langfuse secrets and deploy the helm chart
# The chart is deployed via DevOps pipeline, although secrets are deployed via remote-exec command to avoid storing credentials
# in pipeline paramters
# TODO, see how to use https://github.com/oracle/oci-secrets-store-csi-driver-provider to provision the secrets from vault
module "langfuse_chart" {
  source                                   = "./modules/apps/langfuse/helm_chart"
  compartment_id                           = local.effective_cluster_compartment_id
  tenancy_ocid                             = var.tenancy_ocid
  region                                   = var.region
  shape_name                               = local.ci_shape_selected
  oci_profile                              = var.oci_profile
  cluster_id                               = local.target_cluster_id
  artifact_repo_id                         = local.artifact_repo_id
  subnet_id                                = local.workload_subnet_id # shell stage needs to reach to the cluster endpoint
  builder_instance_private_ip              = module.builder_instance.details.private_ip
  builder_instance_private_key_secret_ocid = data.external.builder_ssh_key_to_vault.result.private_key_secret_ocid
  psql_endpoint                            = module.langfuse_postgres.details.endpoint
  psql_password                            = module.langfuse_postgres.details.password
  psql_ocid                                = module.langfuse_postgres.details.ocid
  s3_client_id                             = var.langfuse_s3_access_key
  s3_client_secret                         = var.langfuse_s3_secret_key
  idcs_app_id                              = local.idcs_app_id
  idcs_client_id                           = local.idcs_client_id
  idcs_client_secret                       = local.idcs_client_secret
  idcs_domain_url                          = local.idcs_domain_url
  redis_hostname                           = module.langfuse_redis.details.hostname
  redis_password                           = module.langfuse_redis.details.password
  devops_project_id                        = module.devops_setup.project_id
  devops_environment_id                    = module.devops_target_cluster_env.environment_id
  object_storage_bucket                    = local.object_storage_bucket
  deploy_id                                = local.deploy_id
  langfuse_helm_chart_version              = var.langfuse_helm_chart_version
  langfuse_hostname                        = local.langfuse_url
  secrets_store_vault_compartment_id       = var.secrets_store_vault_compartment_id
  secrets_store_vault_id                   = var.secrets_store_vault_id
  secrets_store_key_id                     = var.secrets_store_key_id


  depends_on = [
    module.langfuse_idcs_app,
    # module.nginx_ingress_controller,
    module.istio_deployment_using_addon_manager,
    module.istio_gateway_crds,
    module.langfuse_gateway,
    module.langfuse_postgres,
    module.langfuse_redis,
    oci_objectstorage_bucket.langfuse_bucket,
    module.build_langfuse_image,
    module.cert_manager_deployment_using_addon_manager,
    oci_containerengine_node_pool.oci_oke_node_pool
  ]
}

locals {
  # langfuse_url via Traefik Gateway Load Balancer
  langfuse_web_ip = module.langfuse_gateway.ip_address
  langfuse_url    = local.langfuse_web_ip # "${replace(local.langfuse_web_ip, ".", "-")}.nip.io"
}

output "langfuse_url" {
  value = "https://${local.langfuse_url}/langfuse"
}

# Ingress allows automation of TLS certs creation for the LB using let's encrypt
module "langfuse_gateway_routing" {
  source                = "./modules/apps/langfuse/gateway_routing"
  compartment_id        = local.effective_cluster_compartment_id
  cluster_id            = local.target_cluster_id
  subnet_id             = local.workload_subnet_id
  devops_project_id     = module.devops_setup.project_id
  devops_environment_id = module.devops_target_cluster_env.environment_id
  langfuse_hostname     = local.langfuse_url
  artifact_repo_id      = oci_artifacts_repository.artifact_repository.id
  defined_tags          = var.defined_tags
  shape_name            = local.ci_shape_selected

  depends_on = [
    module.cert_manager_deployment_using_addon_manager,
    module.istio_deployment_using_addon_manager,
    # module.langfuse_chart
  ]
}
