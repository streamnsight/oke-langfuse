## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

module "secrets_cleanup" {
  source      = "../../../secrets/secrets_cleanup"
  oci_profile = var.oci_profile
  secret_ids  = values(data.external.create_langfuse_vault_secrets.result)
  depends_on = [
    data.external.create_langfuse_vault_secrets
  ]
}
