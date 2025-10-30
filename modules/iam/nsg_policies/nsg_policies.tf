locals {
  policy_statements = compact([
    for permission in var.permissions : "Allow any-user to ${permission} in compartment id ${var.compartment_id} where ALL {request.networkSource.name='${var.nsg_name}'}"
  ])
}

output "policy_statements" {
  value = local.policy_statements
}

