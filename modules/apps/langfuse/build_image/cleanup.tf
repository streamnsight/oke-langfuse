## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "null_resource" "langfuse_ocir_repo_cleanup" {
  triggers = {
    deploy_id         = var.deploy_id
    tenancy_namespace = var.tenancy_namespace
    compartment_id    = var.compartment_id
    profile           = var.oci_profile
  }

  depends_on = [
    module.build_langfuse_image_shell_stage
  ]

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      set -e
      REPO_NAME="${self.triggers.tenancy_namespace}/${self.triggers.deploy_id}/langfuse"
      REPO_ID=$(oci artifacts container repository list \
        --profile ${self.triggers.profile} \
        --compartment-id ${self.triggers.compartment_id} \
        --all \
        --query "data.items[?\"display-name\"=='${self.triggers.deploy_id}/langfuse'].id | [0]" \
        --raw-output | tr -d '\r')
      if [ -n "$REPO_ID" ] && [ "$REPO_ID" != "null" ]; then
        oci artifacts container repository delete --profile ${self.triggers.profile} --repository-id "$REPO_ID" --force
      else
        echo "OCIR repo $REPO_NAME not found; skipping delete."
      fi
    CMD
  }
  # trigger only on actual terraform destroy
  # otehrwise may be triggered by any update / replace
  lifecycle { ignore_changes = [triggers] }
}
