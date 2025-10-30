
locals {
  policy_statements = compact([
    for permission in var.permissions : "Allow any-user to ${permission} in compartment id ${var.compartment_id} where ALL {request.principal.type='workload', request.principal.namespace ='${var.namespace}', request.principal.service_account = '${var.service_account_name}', request.principal.cluster_id = '${var.cluster_id}'}"
  ])
}

# resource "oci_identity_policy" "workload_identity" {
#   count          = var.create_policy ? 1 : 0
#   compartment_id = var.compartment_id
#   name           = "${replace(lower(var.workload_name), " ", "_")}_policy_${substr(var.cluster_id, -4, -1)}"
#   description    = "${title(var.workload_name)} Policy for Cluster ${var.cluster_id}"
#   statements     = local.policy_statements
#   defined_tags   = var.defined_tags
# }

output "policy_statements" {
  value = local.policy_statements
}