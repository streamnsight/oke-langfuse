## Copyright © 2022-2024, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# # Policy needed for nodes to access the user defined encryption key if it was requested
# resource "oci_identity_policy" "oke_key_access_policy" {
#   count = (var.enable_secret_encryption && var.secrets_key_id != null) || (var.enable_image_validation && var.image_validation_key_id != null) ? 1 : 0
#   #Required
#   compartment_id = var.tenancy_ocid
#   description    = "key access policy for OKE ${random_string.deploy_id.result}"
#   name           = "oke_key_access${random_string.deploy_id.result}"
#   statements = compact([
#     var.enable_secret_encryption && var.secrets_key_id != null ? "Allow any-user to use keys in tenancy where ALL {request.principal.type = 'cluster', target.key.id='${var.secrets_key_id}'}" : "",
#     var.enable_image_validation && var.image_validation_key_id != null ? "Allow any-user to use keys in tenancy where ALL {request.principal.type = 'cluster', target.key.id='${var.image_validation_key_id}'}" : ""
#   ])
# }

# ### Dynanmic group for OKE Nodes
# # This dynaimc group cover the nodes and cluster
# # along with the policy, it is needed to pull images from OCIR
# resource "oci_identity_dynamic_group" "oke_nodes_dg" {
#   #Required
#   compartment_id = var.tenancy_ocid
#   description    = "OKE nodes for ${local.cluster_name}"
#   matching_rule  = "ANY { instance.compartment.id = '${var.cluster_compartment_id}', ALL { resource.cluster_compartment.id = '${var.cluster_compartment_id}', ANY { resource.type = 'instance', resource.type = 'cluster'} } }"
#   name           = local.worker_nodes_dg_name
#   defined_tags   = var.defined_tags
#   provider       = oci.home_region
#   lifecycle {
#     ignore_changes = [defined_tags]
#   }
# }

locals {
  nsg_name = "${local.cluster_name_sanitized}-nodes"
}

# Network Source for the cluster nodes
module "network_source_group" {
  count = var.use_network_source ? 1 : 0
  source        = "./modules/iam/network_source"
  nsg_name      = local.nsg_name
  tenancy_ocid  = var.tenancy_ocid
  vcn_id        = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id
  subnets_cidrs = local.node_pool_subnets_cidrs
  providers = {
    oci = oci.home_region
  }
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
  source         = "./modules/iam/nsg_policies"
  nsg_name       = local.nsg_name
  compartment_id = var.cluster_compartment_id
  permissions = local.cluster_node_permissions
  use_nsg = var.use_network_source
  providers = {
    oci = oci.home_region
  }
}


module "policies" {
  source         = "./modules/iam/policy"
  compartment_id = var.cluster_compartment_id
  description    = "Policies for ${local.cluster_name}"
  policy_statements = concat(
    module.nsg_based_policies.policy_statements,
    module.cluster_autoscaler_workload_identity_policy.policy_statements
  )
  providers = {
    oci = oci.home_region
  }
}

# resource "oci_identity_policy" "cluster-node-policies" {
#   compartment_id = var.cluster_compartment_id
#   name           = "OKE-nodes-dg-policy"
#   description    = "OKE nodes policy"
#   statements     = local.worker_nodes_policy_statements
#   provider       = oci.home_region
#   defined_tags   = var.defined_tags
#   lifecycle {
#     ignore_changes = [defined_tags]
#   }
# }

