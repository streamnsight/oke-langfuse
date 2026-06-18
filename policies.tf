## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl


locals {
  nsg_name = "${local.cluster_name_sanitized}-nodes"
}

# Network Source for the cluster nodes
module "network_source_group" {
  count         = var.use_network_source ? 1 : 0
  source        = "./modules/iam/network_source"
  nsg_name      = local.nsg_name
  tenancy_ocid  = var.tenancy_ocid
  vcn_id        = local.effective_vcn_id
  subnets_cidrs = local.node_pool_subnets_cidrs
  providers = {
    oci = oci.home_region
  }
}

locals {
  cluster_nodes = "ALL { request.principal.type = 'instance' , request.principal.compartment.id = '${local.effective_cluster_compartment_id}' }"
  cluster_principal = "ALL { request.principal.type = 'cluster', request.principal.cluster_id = '${local.target_cluster_id}' }"
  worker_nodes_policy_statements = var.use_network_source ? [] : compact([
    "allow any-user to read repos in compartment id ${var.devops_compartment_id} where ${local.cluster_nodes}",
    "allow any-user to manage generative-ai-family in compartment id ${local.effective_cluster_compartment_id} where ${local.cluster_nodes}",
  ])
  langfuse_certificate_policy_statements = var.langfuse_use_custom_domain ? [
    "allow any-user to read leaf-certificate-family in compartment id ${local.effective_cluster_compartment_id} where ${local.cluster_principal}"
  ] : []
}

# Policy for OKE nodes to read repos and be able to pull container images from OCIR
# The policy is needed along with the cloud-init script set on the nodes, which 
# creates the docker credentials so no pullSecret is needed.
# locals {
#   worker_nodes_dg_name = "${local.cluster_name_sanitized}-nodes"
#   worker_nodes_policy_statements = compact([
#     "allow dynamic-group ${local.worker_nodes_dg_name} to read repos in compartment id ${var.devops_compartment_id}"
#   ])
# }

locals {
  cluster_node_permissions = [
    "read repos",
    "manage generative-ai-family"
  ]
}

module "nsg_based_policies" {
  count          = var.use_network_source ? 1 : 0
  source         = "./modules/iam/nsg_policies"
  nsg_name       = local.nsg_name
  compartment_id = local.effective_cluster_compartment_id
  permissions    = local.cluster_node_permissions
  providers = {
    oci = oci.home_region
  }
}


module "policies_before_node_pool" {
  source         = "./modules/iam/policy"
  compartment_id = local.effective_cluster_compartment_id
  description    = "Policies for ${local.cluster_name} nodes"
  policy_statements = flatten(compact(concat(
    coalesce(local.worker_nodes_policy_statements, []),
    local.langfuse_certificate_policy_statements,
    var.use_network_source ? module.nsg_based_policies[0].policy_statements : []
  )))
  providers = {
    oci = oci.home_region
  }
}

module "policies_after_node_pool" {
  count             = local.cluster_autoscaler_enabled ? 1 : 0
  source            = "./modules/iam/policy"
  compartment_id    = local.effective_cluster_compartment_id
  description       = "Policies for ${local.cluster_name} add-ons"
  policy_statements = module.cluster_autoscaler_workload_identity_policy[0].policy_statements
  providers = {
    oci = oci.home_region
  }
  depends_on = [oci_containerengine_node_pool.oci_oke_node_pool]
}
