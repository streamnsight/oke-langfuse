## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

module "secrets_cleanup" {
  source      = "../../secrets/secrets_cleanup"
  oci_profile = var.oci_profile
  secret_ids  = values(data.external.create_oci_genai_gateway_vault_secrets.result)
  depends_on = [
    data.external.create_oci_genai_gateway_vault_secrets
  ]
}

resource "null_resource" "oci_genai_gateway_ocir_repo_cleanup" {
  triggers = {
    deploy_id         = var.deploy_id
    tenancy_namespace = var.tenancy_namespace
    compartment_id    = var.compartment_id
  }

  depends_on = [
    module.build_oci_genai_gateway_image_shell_stage
  ]

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      set -e
      REPO_NAME="${self.triggers.tenancy_namespace}/${self.triggers.deploy_id}/oci-genai-gateway"
      REPO_ID=$(oci artifacts container repository list \
        --compartment-id ${self.triggers.compartment_id} \
        --all \
        --query "data.items[?\"display-name\"=='${self.triggers.deploy_id}/oci-genai-gateway'].id | [0]" \
        --raw-output | tr -d '\r')
      if [ -n "$REPO_ID" ] && [ "$REPO_ID" != "null" ]; then
        oci artifacts container repository delete --repository-id "$REPO_ID" --force
      else
        echo "OCIR repo $REPO_NAME not found; skipping delete."
      fi
    CMD
  }
  lifecycle { ignore_changes = [triggers] }
}

