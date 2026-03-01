## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl


data "external" "create_langfuse_vault_secrets" {
  program = ["${path.module}/scripts/create_vault_secrets.sh"]
  query = {
    deploy_id                          = var.deploy_id
    profile                            = var.oci_profile
    secrets_store_vault_compartment_id = var.secrets_store_vault_compartment_id
    secrets_store_vault_id             = var.secrets_store_vault_id
    secrets_store_key_id               = var.secrets_store_key_id
    idcs_client_id                     = var.idcs_client_id
    idcs_client_secret                 = var.idcs_client_secret
    idcs_issuer                        = var.idcs_domain_url
    s3_access_key                      = var.s3_client_id
    s3_secret_key                      = var.s3_client_secret
    psql_password                      = var.psql_password
    psql_url                           = "postgresql://langfuse:${urlencode(var.psql_password)}@${var.psql_endpoint.fqdn}:${var.psql_endpoint.port}/postgres?sslmode=verify-full&sslrootcert=/secrets/db-keystore/CaCertificate-langfuse.pub"
  }
}

resource "oci_generic_artifacts_content_artifact_by_path" "create_langfuse_secrets_script_artifact" {
  #Required
  artifact_path = "create_oke_secrets.sh"
  repository_id = var.artifact_repo_id
  version       = "0.1.0"
  content       = file("${path.module}/scripts/create_oke_secrets.sh")

  # delete the resource from artifact repo on destroy as it blocks destroy of the artifact repo itself
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      oci artifacts generic artifact delete --artifact-id ${self.id} --force
    CMD
  }
}

module "langfuse_secrets_shell_stage" {
  source                = "../../../devops/deployment_stages/shell_stage"
  compartment_id        = var.compartment_id
  subnet_id             = var.subnet_id
  stage_name            = "langfuse_secrets"
  devops_project_id     = var.devops_project_id
  devops_environment_id = var.devops_environment_id
  deploy_pipeline_parameters = [
    {
      name          = "SSH_PRIVATE_KEY_SECRET_OCID"
      default_value = var.builder_instance_private_key_secret_ocid
      description   = "Private key for access to builder instance"
    },
    {
      name          = "BUILDER_INSTANCE_IP"
      default_value = var.builder_instance_private_ip
      description   = "setupo script"
    },
    {
      name          = "CREATE_LANGFUSE_SECRETS_ARTIFACT_OCID"
      default_value = oci_generic_artifacts_content_artifact_by_path.create_langfuse_secrets_script_artifact.id
      description   = "OCID of the artifact"
    },
    {
      name          = "LETSENCRYPT_CLUSTERISSUER_ARTIFACT_OCID"
      default_value = oci_generic_artifacts_content_artifact_by_path.create_cluster_issuers_artifact.id
      description   = "OCID of the artifact"
    },
    {
      name          = "REGISTRY_OCID"
      default_value = var.artifact_repo_id
      description   = "OCID of the artifact repository"
    },
    {
      name          = "REGION"
      default_value = var.region
      description   = "cluster region"
    },
    {
      name          = "PROFILE"
      default_value = var.oci_profile
      description   = "OCI Profile"
    },
    {
      name          = "CLUSTER_ID"
      default_value = var.cluster_id
      description   = "Cluster ID"
    },
    {
      name          = "DEPLOY_ID"
      default_value = var.deploy_id
      description   = "DEPLOY ID"
    },
    {
      name          = "SECRET_STORE_VAULT_ID"
      default_value = var.secrets_store_vault_id
      description   = "OCID of the vault"
    },
    {
      name          = "SECRET_STORE_KEY_ID"
      default_value = var.secrets_store_key_id
      description   = "OCID of the key"
    },
    {
      name          = "COMPARTMENT_ID"
      default_value = var.secrets_store_vault_compartment_id
      description   = "Compartment ID"
    },
    {
      name          = "PSQL_OCID"
      default_value = var.psql_ocid
      description   = "PSQL OCID"
    }
  ]
  command_spec_content = file("${path.module}/scripts/command_spec.yaml")
  depends_on = [
    data.external.create_langfuse_vault_secrets
  ]
}
