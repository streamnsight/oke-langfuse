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
  object_storage_bucket                  = "langfuse-${local.deploy_id}-traces"
  langfuse_custom_domain_fqdn_normalized = trimspace(var.langfuse_custom_domain_fqdn != null ? var.langfuse_custom_domain_fqdn : "")
  langfuse_legacy_certificate_provided = (
    (var.langfuse_certificate_ocid != null && var.langfuse_certificate_ocid != "") ||
    (nonsensitive(var.langfuse_certificate_pem) != null && nonsensitive(var.langfuse_certificate_pem) != "") ||
    (nonsensitive(var.langfuse_private_key_pem) != null && nonsensitive(var.langfuse_private_key_pem) != "") ||
    (nonsensitive(var.langfuse_certificate_chain_pem) != null && nonsensitive(var.langfuse_certificate_chain_pem) != "")
  )
  langfuse_effective_has_provided_certificate = var.langfuse_has_provided_certificate || local.langfuse_legacy_certificate_provided
  langfuse_tls_mode = var.langfuse_tls_mode != null ? var.langfuse_tls_mode : (
    !var.langfuse_enable_tls ? "none" : (
      !var.langfuse_use_custom_domain ? "ip_letsencrypt_http01" : (
        local.langfuse_effective_has_provided_certificate ? var.langfuse_certificate_source : "domain_letsencrypt_http01"
      )
    )
  )
  langfuse_import_certificate   = var.langfuse_use_custom_domain && local.langfuse_tls_mode == "import_certificate_pem"
  langfuse_uses_oci_certificate = var.langfuse_use_custom_domain && contains(["existing_oci_certificate", "import_certificate_pem"], local.langfuse_tls_mode)
  langfuse_uses_letsencrypt     = contains(["ip_letsencrypt_http01", "domain_letsencrypt_http01"], local.langfuse_tls_mode)
  langfuse_protocol             = local.langfuse_tls_mode == "none" ? "http" : "https"
}

resource "terraform_data" "langfuse_custom_domain_validation" {
  input = {
    use_custom_domain  = var.langfuse_use_custom_domain
    enable_tls         = var.langfuse_enable_tls
    provided_cert      = var.langfuse_has_provided_certificate
    certificate_source = var.langfuse_certificate_source
  }

  lifecycle {
    precondition {
      condition = !var.langfuse_use_custom_domain || can(regex(
        "^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
        local.langfuse_custom_domain_fqdn_normalized
      ))
      error_message = "langfuse_custom_domain_fqdn must be a fully qualified domain name without a scheme or path when langfuse_use_custom_domain is true."
    }

    precondition {
      condition     = local.langfuse_tls_mode != "ip_letsencrypt_http01" || !var.langfuse_use_custom_domain
      error_message = "langfuse_tls_mode ip_letsencrypt_http01 can only be used when langfuse_use_custom_domain is false."
    }

    precondition {
      condition     = local.langfuse_tls_mode != "domain_letsencrypt_http01" || var.langfuse_use_custom_domain
      error_message = "langfuse_tls_mode domain_letsencrypt_http01 requires langfuse_use_custom_domain to be true."
    }

    precondition {
      condition     = local.langfuse_tls_mode != "domain_letsencrypt_http01" || var.langfuse_letsencrypt_challenge_type == "http01"
      error_message = "Only the http01 Let's Encrypt challenge type is currently supported for custom-domain certificates."
    }

    precondition {
      condition     = !contains(["existing_oci_certificate", "import_certificate_pem"], local.langfuse_tls_mode) || var.langfuse_use_custom_domain
      error_message = "langfuse_tls_mode existing_oci_certificate and import_certificate_pem require langfuse_use_custom_domain to be true."
    }

    precondition {
      condition     = local.langfuse_tls_mode != "existing_oci_certificate" || (var.langfuse_certificate_ocid != null && var.langfuse_certificate_ocid != "")
      error_message = "langfuse_certificate_ocid is required when langfuse_tls_mode is existing_oci_certificate."
    }

    precondition {
      condition = local.langfuse_tls_mode != "import_certificate_pem" || (
        var.langfuse_certificate_pem != null && var.langfuse_certificate_pem != "" &&
        var.langfuse_private_key_pem != null && var.langfuse_private_key_pem != "" &&
        var.langfuse_certificate_chain_pem != null && var.langfuse_certificate_chain_pem != ""
      )
      error_message = "langfuse_certificate_pem, langfuse_private_key_pem, and langfuse_certificate_chain_pem are required when langfuse_tls_mode is import_certificate_pem."
    }
  }
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

resource "oci_certificates_management_certificate" "langfuse_custom_domain" {
  count = local.langfuse_import_certificate ? 1 : 0

  compartment_id = local.effective_cluster_compartment_id
  name           = "langfuse-${local.deploy_id}-custom-domain"

  certificate_config {
    config_type              = "IMPORTED"
    certificate_profile_type = "TLS_SERVER_OR_CLIENT"
    certificate_pem          = var.langfuse_certificate_pem
    private_key_pem          = var.langfuse_private_key_pem
    cert_chain_pem           = var.langfuse_certificate_chain_pem
  }

  defined_tags = var.defined_tags

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

locals {
  langfuse_effective_certificate_ocid = local.langfuse_uses_oci_certificate ? (
    local.langfuse_import_certificate ? oci_certificates_management_certificate.langfuse_custom_domain[0].id : var.langfuse_certificate_ocid
  ) : ""
}

# Create the IDCS app with the proper redirect URL
module "langfuse_idcs_app" {
  count              = var.create_idcs_app ? 1 : 0
  source             = "./modules/iam/idcs_app"
  identity_domain_id = var.identity_domain_id
  display_name       = local.cluster_name_sanitized
  redirect_url       = "${local.langfuse_protocol}://${local.langfuse_url}/langfuse/api/auth/callback/custom"
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
  source                    = "./modules/apps/langfuse/gateway"
  compartment_id            = local.effective_cluster_compartment_id
  cluster_id                = local.target_cluster_id
  subnet_id                 = local.workload_subnet_id
  devops_project_id         = module.devops_setup.project_id
  devops_environment_id     = module.devops_target_cluster_env.environment_id
  artifact_repo_id          = oci_artifacts_repository.artifact_repository.id
  shape_name                = local.ci_shape_selected
  tls_mode                  = local.langfuse_tls_mode
  langfuse_certificate_ocid = local.langfuse_effective_certificate_ocid
  depends_on = [
    terraform_data.langfuse_custom_domain_validation,
    module.policies_before_node_pool,
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
  langfuse_protocol                        = local.langfuse_protocol
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
  # langfuse_url is the hostname Langfuse uses in redirects and routes.
  langfuse_web_ip = module.langfuse_gateway.ip_address
  langfuse_url    = var.langfuse_use_custom_domain ? local.langfuse_custom_domain_fqdn_normalized : local.langfuse_web_ip
}

output "langfuse_url" {
  value = "${local.langfuse_protocol}://${local.langfuse_url}/langfuse"
}

output "langfuse_load_balancer_ip" {
  value = local.langfuse_web_ip
}

# Ingress allows automation of TLS certs creation for the LB using let's encrypt
module "langfuse_gateway_routing" {
  source                          = "./modules/apps/langfuse/gateway_routing"
  compartment_id                  = local.effective_cluster_compartment_id
  cluster_id                      = local.target_cluster_id
  subnet_id                       = local.workload_subnet_id
  devops_project_id               = module.devops_setup.project_id
  devops_environment_id           = module.devops_target_cluster_env.environment_id
  langfuse_hostname               = local.langfuse_url
  artifact_repo_id                = oci_artifacts_repository.artifact_repository.id
  defined_tags                    = var.defined_tags
  shape_name                      = local.ci_shape_selected
  tls_mode                        = local.langfuse_tls_mode
  enable_cert_manager_gateway_api = local.langfuse_uses_letsencrypt

  depends_on = [
    module.cert_manager_deployment_using_addon_manager,
    module.istio_deployment_using_addon_manager,
    module.langfuse_gateway,
    # module.langfuse_chart
  ]
}
