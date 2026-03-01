## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

module "secrets_cleanup" {
  source = "../../../secrets/secrets_cleanup"
  oci_profile = var.oci_profile
  secret_ids = values(data.external.create_langfuse_vault_secrets.result)
    #   data.external.create_langfuse_vault_secrets.result.encryption_key_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.salt_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.nextauth_secret_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.clickhouse_password_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.redis_password_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.idcs_client_id_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.idcs_client_secret_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.idcs_issuer_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.s3_access_key_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.s3_secret_key_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.psql_password_secret_id,
    #   data.external.create_langfuse_vault_secrets.result.psql_url_secret_id,
    # ]
  depends_on = [
    data.external.create_langfuse_vault_secrets
  ]
}
