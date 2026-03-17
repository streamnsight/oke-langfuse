## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# deploys the OCI Gen AI Gateway project that provides an OpenAI compatible API endpoint for OCI Gen AI service
# needed to use evaluation features of LangFuse.
module "oci_genai_gateway" {
  source                                   = "./modules/apps/oci_genai_gateway"
  compartment_id                           = var.cluster_compartment_id
  tenancy_ocid                             = var.tenancy_ocid
  tenancy_namespace                        = data.oci_objectstorage_namespace.ns.namespace
  deploy_id                                = local.deploy_id
  shape_name                               = local.ci_shape_selected
  region                                   = var.region
  genai_region                             = var.oci_genai_region
  oci_genai_gateway_tag                    = var.oci_genai_gateway_tag
  devops_project_id                        = module.devops_setup.project_id
  devops_environment_id                    = module.devops_target_cluster_env.environment_id
  artifact_repo_id                         = local.artifact_repo_id
  subnet_id                                = local.workload_subnet_id
  builder_instance_private_ip              = module.builder_instance.details.private_ip
  builder_instance_private_key_secret_ocid = data.external.builder_ssh_key_to_vault.result.private_key_secret_ocid
  secrets_store_vault_compartment_id       = var.secrets_store_vault_compartment_id
  secrets_store_vault_id                   = var.secrets_store_vault_id
  secrets_store_key_id                     = var.secrets_store_key_id
  cluster_id                               = local.target_cluster_id
  depends_on                               = [module.builder_setup_shell_stage]
}

# output "oci_genai_gateway_default_api_key" {
#   value = module.oci_genai_gateway.default_api_key
# }

output "oci_genai_gateway_endpoint_url" {
  value = "http://oci-genai-gateway:8088/v1"
}
