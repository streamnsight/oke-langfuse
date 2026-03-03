## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  policy_statements = compact([
    for permission in var.permissions : "Allow any-user to ${permission} in compartment id ${var.compartment_id} where ALL {request.principal.type='workload', request.principal.namespace ='${var.namespace}', request.principal.service_account = '${var.service_account_name}', request.principal.cluster_id = '${var.cluster_id}'}"
  ])
}

output "policy_statements" {
  value = local.policy_statements
}
