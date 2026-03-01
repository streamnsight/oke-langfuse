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
}


# resource "null_resource" "langfuse_vault_secrets_schedule_deletion" {
#   triggers = {
#     profile = var.oci_profile
#     secret_ids_json = jsonencode([
#       data.external.create_oci_genai_gateway_vault_secrets.result.oci_genai_gateway_default_api_key_secret_id
#     ])
#   }

#   provisioner "local-exec" {
#     when        = destroy
#     interpreter = ["/bin/bash", "-c"]
#     command     = <<-CMD
#       set -euo pipefail

#       PROFILE="${self.triggers.profile}"
#       SECRET_IDS_JSON='${self.triggers.secret_ids_json}'

#       start_minutes=10
#       max_minutes=2880

#       rfc3339_utc_in_minutes() {
#         local minutes="$1"

#         if date -u -d "+$${minutes} minutes" +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
#           date -u -d "+$${minutes} minutes" +"%Y-%m-%dT%H:%M:%SZ"
#           return 0
#         fi

#         if date -u -v+"$${minutes}"M +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
#           date -u -v+"$${minutes}"M +"%Y-%m-%dT%H:%M:%SZ"
#           return 0
#         fi

#         echo "ERROR: could not compute future UTC time; unsupported date implementation" >&2
#         return 1
#       }

#       for secret_id in $(echo "$SECRET_IDS_JSON" | jq -r '.[]'); do
#         if [ -z "$secret_id" ] || [ "$secret_id" = "null" ]; then
#           continue
#         fi

#         minutes=$start_minutes
#         scheduled=false

#         while [ $minutes -le $max_minutes ]; do
#           deletion_time=$(rfc3339_utc_in_minutes "$minutes")

#           if oci vault secret schedule-secret-deletion \
#             --secret-id "$secret_id" \
#             --time-of-deletion "$deletion_time" \
#             --profile "$PROFILE" >/dev/null 2>&1; then
#             echo "Scheduled deletion for $secret_id at $deletion_time" >&2
#             scheduled=true
#             break
#           fi

#           lifecycle_state=$(oci vault secret get \
#             --secret-id "$secret_id" \
#             --profile "$PROFILE" \
#             --query 'data."lifecycle-state"' \
#             --raw-output 2>/dev/null || true)

#           if [ "$lifecycle_state" = "PENDING_DELETION" ]; then
#             echo "Secret $secret_id already pending deletion" >&2
#             scheduled=true
#             break
#           fi

#           minutes=$((minutes * 2))
#         done

#         if [ "$scheduled" != "true" ]; then
#           echo "Failed to schedule deletion for $secret_id with retention up to $${max_minutes} minutes" >&2
#           exit 1
#         fi
#       done
#     CMD
#   }

#   depends_on = [
#     data.external.create_oci_genai_gateway_vault_secrets
#   ]
# }
