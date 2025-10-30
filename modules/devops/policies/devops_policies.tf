locals {
  devops_policy_statements = [
    "allow any-user to use ons-topic in compartment id ${var.devops_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
    "allow any-user to use logging-family in compartment id ${var.devops_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
    "allow any-user to use network-security-groups in compartment id ${var.vcn_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
    "allow any-user to use subnets in compartment id ${var.vcn_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
    "allow any-user to use vnics in compartment id ${var.vcn_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
    "allow any-user to use devops-project in compartment id ${var.devops_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
    "allow any-user to use devops-deploy-artifact in compartment id ${var.devops_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
    "allow any-user to use devops-deploy-environment in compartment id ${var.devops_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
    "allow any-user to manage clusters in compartment id ${var.cluster_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
    "allow any-user to read all-artifacts in compartment id ${var.devops_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
    "allow any-user to use repos in compartment id ${var.devops_compartment_id} where all {request.principal.type = 'devopsdeploypipeline', target.compartment.id = '${var.devops_compartment_id}'}",
  ]
}

resource "oci_identity_policy" "devops-pipeline-policies" {
  compartment_id = var.devops_compartment_id
  name           = "devops_policies_for_${var.cluster_name}"
  description    = "Devops deploy pipeline policy for cluster ${var.cluster_name}"
  statements     = local.devops_policy_statements
  defined_tags   = var.defined_tags
  lifecycle {
    ignore_changes = [defined_tags]
  }
}