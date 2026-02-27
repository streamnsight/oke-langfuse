## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_devops_repository" "repository" {
  #Required
  name            = var.name
  project_id      = var.project_id
  repository_type = "HOSTED"

  #Optional
  default_branch = "refs/heads/main"
  defined_tags   = var.defined_tags
  description    = var.description

  lifecycle {
    ignore_changes = [defined_tags]
  }
}
