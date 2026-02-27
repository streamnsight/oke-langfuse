## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl


# module "oci_genai_gateway_secrets_shell_stage" {
#   source                = "../../../devops/deployment_stages/shell_stage"
#   compartment_id        = var.compartment_id
#   subnet_id             = var.subnet_id
#   stage_name            = "oci_genai_gateway_secrets"
#   devops_project_id     = var.devops_project_id
#   devops_environment_id = var.devops_environment_id
#   deploy_pipeline_parameters = [
#     {
#       name          = "SSH_PRIVATE_KEY_SECRET_OCID"
#       default_value = var.builder_instance_private_key_secret_ocid
#       description   = "Private key for access to builder instance"
#     },
#     {
#       name          = "BUILDER_INSTANCE_IP"
#       default_value = var.builder_instance_private_ip
#       description   = "setupo script"
#     },
#     {
#       name          = "CREATE_OCI_GENAI_GATEWAY_OKE_SECRETS_ARTIFACT_OCID"
#       default_value = oci_generic_artifacts_content_artifact_by_path.create_oci_genai_gateway_oke_secrets_script_artifact.id
#       description   = "OCID of the artifact"
#     },
#     {
#       name          = "OCI_GENAI_GATEWAY_IMAGE_BUILD_ARTIFACT_OCID"
#       default_value = oci_generic_artifacts_content_artifact_by_path.create_cluster_issuers_artifact.id
#       description   = "OCID of the artifact"
#     },
#     {
#       name          = "REGISTRY_OCID"
#       default_value = var.artifact_repo_id
#       description   = "OCID of the artifact repository"
#     },
#     {
#       name          = "REGION"
#       default_value = var.region
#       description   = "cluster region"
#     },
#     {
#       name          = "PROFILE"
#       default_value = var.oci_profile
#       description   = "OCI Profile"
#     },
#     {
#       name          = "CLUSTER_ID"
#       default_value = var.cluster_id
#       description   = "Cluster ID"
#     },
#     {
#       name          = "DEPLOY_ID"
#       default_value = var.deploy_id
#       description   = "DEPLOY ID"
#     },
#     {
#       name          = "SECRET_STORE_VAULT_ID"
#       default_value = var.secrets_store_vault_id
#       description   = "OCID of the vault"
#     },
#     {
#       name          = "SECRET_STORE_KEY_ID"
#       default_value = var.secrets_store_key_id
#       description   = "OCID of the key"
#     },
#     {
#       name          = "COMPARTMENT_ID"
#       default_value = var.secrets_store_vault_compartment_id
#       description   = "Compartment ID"
#     },
#   ]
#   command_spec_content = file("${path.module}/scripts/command_spec.yaml")
#   depends_on = [
#     data.external.create_langfuse_vault_secrets
#   ]
# }
