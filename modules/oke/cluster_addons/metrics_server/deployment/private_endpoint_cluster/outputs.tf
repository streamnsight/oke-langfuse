## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "repos" {
  value = local.repos
}

output "stage" {
  value = oci_devops_deploy_stage.metrics-server
}
