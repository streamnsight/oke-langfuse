## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "null_resource" "langfuse_vault_secrets_schedule_deletion" {
  triggers = {
    profile         = var.oci_profile
    secret_ids_json = jsonencode(sort(var.secret_ids))
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
  lifecycle { ignore_changes = [triggers] }
}
