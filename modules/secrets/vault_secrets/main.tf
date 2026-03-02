## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

data "external" "ensure_vault_secrets" {
  program = ["${path.module}/scripts/ensure_vault_secrets.sh"]
  query = {
    profile        = var.profile
    compartment_id = var.compartment_id
    vault_id       = var.vault_id
    key_id         = var.key_id
    secrets_json   = jsonencode(var.secrets)
  }
}

locals {
  secret_ocids_by_name = jsondecode(data.external.ensure_vault_secrets.result.secret_ocids_json)
}
