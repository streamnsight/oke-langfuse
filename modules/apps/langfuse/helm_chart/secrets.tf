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

resource "null_resource" "langfuse_vault_secrets_schedule_deletion" {
  triggers = {
    profile = var.oci_profile
    secret_ids_json = jsonencode([
      data.external.create_langfuse_vault_secrets.result.encryption_key_secret_id,
      data.external.create_langfuse_vault_secrets.result.salt_secret_id,
      data.external.create_langfuse_vault_secrets.result.nextauth_secret_secret_id,
      data.external.create_langfuse_vault_secrets.result.clickhouse_password_secret_id,
      data.external.create_langfuse_vault_secrets.result.redis_password_secret_id,
      data.external.create_langfuse_vault_secrets.result.idcs_client_id_secret_id,
      data.external.create_langfuse_vault_secrets.result.idcs_client_secret_secret_id,
      data.external.create_langfuse_vault_secrets.result.idcs_issuer_secret_id,
      data.external.create_langfuse_vault_secrets.result.s3_access_key_secret_id,
      data.external.create_langfuse_vault_secrets.result.s3_secret_key_secret_id,
      data.external.create_langfuse_vault_secrets.result.psql_password_secret_id,
      data.external.create_langfuse_vault_secrets.result.psql_url_secret_id,
    ])
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-CMD
      set -euo pipefail

      PROFILE="${self.triggers.profile}"
      SECRET_IDS_JSON='${self.triggers.secret_ids_json}'

      start_minutes=10
      max_minutes=2880

      rfc3339_utc_in_minutes() {
        local minutes="$1"

        if date -u -d "+$${minutes} minutes" +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
          date -u -d "+$${minutes} minutes" +"%Y-%m-%dT%H:%M:%SZ"
          return 0
        fi

        if date -u -v+"$${minutes}"M +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
          date -u -v+"$${minutes}"M +"%Y-%m-%dT%H:%M:%SZ"
          return 0
        fi

        echo "ERROR: could not compute future UTC time; unsupported date implementation" >&2
        return 1
      }

      for secret_id in $(echo "$SECRET_IDS_JSON" | jq -r '.[]'); do
        if [ -z "$secret_id" ] || [ "$secret_id" = "null" ]; then
          continue
        fi

        minutes=$start_minutes
        scheduled=false

        while [ $minutes -le $max_minutes ]; do
          deletion_time=$(rfc3339_utc_in_minutes "$minutes")

          if oci vault secret schedule-secret-deletion \
            --secret-id "$secret_id" \
            --time-of-deletion "$deletion_time" \
            --profile "$PROFILE" >/dev/null 2>&1; then
            echo "Scheduled deletion for $secret_id at $deletion_time" >&2
            scheduled=true
            break
          fi

          lifecycle_state=$(oci vault secret get \
            --secret-id "$secret_id" \
            --profile "$PROFILE" \
            --query 'data."lifecycle-state"' \
            --raw-output 2>/dev/null || true)

          if [ "$lifecycle_state" = "PENDING_DELETION" ]; then
            echo "Secret $secret_id already pending deletion" >&2
            scheduled=true
            break
          fi

          minutes=$((minutes * 2))
        done

        if [ "$scheduled" != "true" ]; then
          echo "Failed to schedule deletion for $secret_id with retention up to $${max_minutes} minutes" >&2
          exit 1
        fi
      done
    CMD
  }

  depends_on = [
    data.external.create_langfuse_vault_secrets
  ]
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
    # {
    #   name          = "IDCS_CLIENT_ID_SECRET_ID"
    #   default_value = var.idcs_client_id
    #   description   = "IDCS Client ID"
    # },
    # {
    #   name          = "IDCS_CLIENT_SECRET"
    #   default_value = var.idcs_client_secret
    #   description   = "IDCS Client Secret"
    # },
    # {
    #   name          = "IDCS_ISSUER"
    #   default_value = var.idcs_domain_url
    #   description   = "IDCS issuer url"
    # },
    # {
    #   name          = "S3_ACCESS_KEY"
    #   default_value = var.s3_client_id
    #   description   = "S3 client ID"
    # },
    # {
    #   name          = "S3_SECRET_KEY"
    #   default_value = var.s3_client_secret
    #   description   = "S3 client secret"
    # },
    # {
    #   name          = "PSQL_PASSWORD"
    #   default_value = var.psql_password
    #   description   = "PSQL password"
    # },
    {
      name          = "PSQL_OCID"
      default_value = var.psql_ocid
      description   = "PSQL OCID"
    },
    # {
    #   name          = "PSQL_URL"
    #   default_value = "postgresql://langfuse:${urlencode(var.psql_password)}@${var.psql_endpoint.fqdn}:${var.psql_endpoint.port}/postgres?sslmode=verify-full&sslrootcert=/secrets/db-keystore/CaCertificate-langfuse.pub"
    #   description   = "PSQL url"
    # }
  ]
  command_spec_content = file("${path.module}/scripts/command_spec.yaml")
  depends_on = [
    data.external.create_langfuse_vault_secrets
  ]
}








# resource "random_bytes" "langfuse_password_encryption_key" {
#   length = 32
# }

# resource "random_string" "langfuse_password_encryption_salt" {
#   length      = 24
#   special     = false
#   min_lower   = 2
#   min_upper   = 2
#   min_numeric = 4
# }

# resource "random_string" "langfuse_next_auth_secret" {
#   length      = 48
#   special     = false
#   min_lower   = 2
#   min_upper   = 2
#   min_numeric = 4
# }

# resource "random_string" "langfuse_clickhouse_password" {
#   length      = 24
#   special     = false
#   min_lower   = 2
#   min_upper   = 2
#   min_numeric = 4
# }


# resource "local_file" "langfuse_postgres_cert" {
#   content  = var.psql_cert
#   filename = "${path.module}/CaCertificate-langfuse.pub"
# }



# creates secrets for langfuse. We don't want these coded into a manifest stored in artifacts, 
# or passing secrets as ENV variables to a build step
# so this ensures secrets are created without leaving the 
# resource "null_resource" "create_langfuse_secrets" {
#   triggers = {
#     instance_id         = var.builder_details.instance_id
#     script              = file("${path.module}/scripts/create_langfuse_secrets.sh")
#     encryption_key      = random_bytes.langfuse_password_encryption_key.hex
#     salt                = random_string.langfuse_password_encryption_salt.result
#     nextauth_secret     = random_string.langfuse_next_auth_secret.result
#     clickhouse_password = random_string.langfuse_clickhouse_password.result
#     redis_password      = var.redis_password
#     postgres_password   = var.psql_password
#     app_id              = var.idcs_app_id
#   }
#   connection {
#     type        = "ssh"
#     user        = "opc"
#     private_key = var.builder_details.private_key
#     host        = var.builder_details.ip_address
#   }

#   provisioner "file" {
#     source      = "${path.module}/CaCertificate-langfuse.pub"
#     destination = "/home/opc/CaCertificate-langfuse.pub"
#   }

#   provisioner "remote-exec" {
#     when = create
#     # wrap the inline script into a template script file so the file content can be used as a trigger 
#     # and this runs each time the script changes
#     inline = [
#       <<EOF
#             ${templatefile("${path.module}/scripts/create_langfuse_secrets.sh", {
#       encryption_key      = random_bytes.langfuse_password_encryption_key.hex
#       salt                = random_string.langfuse_password_encryption_salt.result
#       nextauth_secret     = random_string.langfuse_next_auth_secret.result
#       clickhouse_password = random_string.langfuse_clickhouse_password.result
#       redis_password      = var.redis_password
#       client_id           = var.idcs_client_id
#       client_secret       = var.idcs_client_secret
#       issuer              = var.idcs_domain_url
#       s3_access_key       = var.s3_client_id
#       s3_secret_key       = var.s3_client_secret
#       postgres_password   = var.psql_password
#       database_url        = "postgresql://langfuse:${urlencode(var.psql_password)}@${var.psql_endpoint.fqdn}:${var.psql_endpoint.port}/postgres?sslmode=verify-full&sslrootcert=/secrets/db-keystore/CaCertificate-langfuse.pub"
# })}
#     EOF
# ]
# }


# depends_on = [
#   null_resource.builder_run,
#   oci_containerengine_node_pool.oci_oke_node_pool,
#   oci_identity_domains_app.idcs_app
# ]
# }
