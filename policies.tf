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
  vcn_id        = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id
  subnets_cidrs = local.node_pool_subnets_cidrs
  providers = {
    oci = oci.home_region
  }
}

locals {
  cluster_nodes = "ALL { request.principal.type = 'instance' , request.principal.compartment.id = '${var.cluster_compartment_id}' }" 
  worker_nodes_policy_statements = var.use_network_source ? [] : compact([
    "allow any-user to read repos in compartment id ${var.cluster_compartment_id} where ${local.cluster_nodes}",
    "allow any-user to manage generative-ai-family in compartment id ${var.cluster_compartment_id} where ${local.cluster_nodes}",
  ])
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
  count         = var.use_network_source ? 1 : 0
  source         = "./modules/iam/nsg_policies"
  nsg_name       = local.nsg_name
  compartment_id = var.cluster_compartment_id
  permissions    = local.cluster_node_permissions
  providers = {
    oci = oci.home_region
  }
}


module "policies_before_node_pool" {
  source         = "./modules/iam/policy"
  compartment_id = var.cluster_compartment_id
  description    = "Policies for ${local.cluster_name} nodes"
  policy_statements = flatten(compact(concat(
    coalesce(local.worker_nodes_policy_statements, []),
    var.use_network_source ? module.nsg_based_policies[0].policy_statements : []
  )))
  providers = {
    oci = oci.home_region
  }
}

module "policies_after_node_pool" {
  source         = "./modules/iam/policy"
  compartment_id = var.cluster_compartment_id
  description    = "Policies for ${local.cluster_name} add-ons"
  policy_statements = flatten(compact(concat(
    module.cluster_autoscaler_workload_identity_policy.policy_statements,
    module.native_ingress_workload_identity_policy.policy_statements,
    module.langfuse_secret_store_csi_provider_workload_identity_policy.policy_statements
  )))
  providers = {
    oci = oci.home_region
  }
}
