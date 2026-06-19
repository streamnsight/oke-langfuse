## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "content" {
  value = {
    areLegacyImdsEndpointsDisabled = "true"
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.sh", {
      docker_login_script             = base64encode(file("${path.module}/scripts/docker_login.sh"))
      docker_credential_helper_script = base64encode(file("${path.module}/scripts/docker-credential-helper-init.sh"))
    }))
  }
}
