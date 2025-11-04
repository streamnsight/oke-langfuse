# Copyright (c) 2021, 2024, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

## This file deploys cluster-autoscaler if needed or requested, using the appropriate method depending on the type of cluster
## Enhanced Cluster use the add-on manager to deploy the add-on; it is managed by OKE
## Basic clusters with public endpoint uses a direct deployment using the kubernetes provider
## Basic clusters with a private endpoint use the DevOps service to create a deployment pipeline and deploy to the cluster.
## If the worker nodes do not have internet access, the public images required are pulled and pushed to the local OCIR registry


locals {
  cluster_autoscaler_enabled = var.enable_cluster_autoscaler == null ? var.np1_enable_autoscaler || var.np2_enable_autoscaler || var.np3_enable_autoscaler : var.enable_cluster_autoscaler
  cluster_autoscaler_permissions = [
    "manage cluster-node-pools",
    "manage instance-family",
    "use subnets",
    "read virtual-network-family",
    "use vnics",
    "inspect compartments"
  ]
}


### Cluster autoscaler permission policies
## Cluster autoscaler can use either a dynamic group, a any-user type policy targeting all worker nodes (Node level security)
## or a workload identity method (permissions limited to the cluster-autoscaler workload)
## Workload identity is a more secure method, and is preferred, although it requires to know the cluster id before creating the policy
## Dynamic group type policy can be setup per compartment for any cluster in that compartment.
## For more granular permission, here we use a Network Security Group tied to the subnet of the worker nodes. 
## It still gives any VM in this subnet the permissions autoscaler gets.

# create policies statements to use workload identity
module "cluster_autoscaler_workload_identity_policy" {
  source               = "./modules/iam/workload_identity"
  compartment_id       = var.cluster_compartment_id
  workload_name        = "cluster-autoscaler"
  service_account_name = "cluster-autoscaler"
  namespace            = "kube-system"
  permissions          = local.cluster_autoscaler_permissions
  defined_tags         = var.defined_tags
  cluster_id           = oci_containerengine_cluster.oci_oke_cluster.id
  providers = {
    oci = oci.home_region
  }
}

# # Create policy using a Network Security group based on the worker node subnet CIDR
# module "cluster_autoscaler_nsg_based_policy" {
#   count                   = !var.cluster_autoscaler_use_workload_identity ? 1 : 0
#   source                  = "./modules/add-ons/cluster_autoscaler/policies/network_group"
#   tenancy_ocid            = var.tenancy_ocid
#   cluster_compartment_id  = var.cluster_compartment_id
#   vcn_compartment_id      = var.vcn_compartment_id
#   vcn_id                  = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id
#   cluster_name            = local.cluster_name_sanitized
#   node_pool_subnets_cidrs = local.node_pool_subnets_cidrs
#   permissions             = local.cluster_autoscaler_permissions
#   providers = {
#     oci = oci.home_region
#   }
# }
### End Cluster autoscaler permission policies


### Deployment methods

# Deployment method for a public or private endpoint cluster when 
# it is an enhanced cluster.
# This method uses the cluster add-on resource for enhanced clusters
module "cluster_autoscaler_deployment_with_addon_manager" {
  count                                               = local.cluster_autoscaler_enabled ? (local.use_addon_manager ? 1 : 0) : 0
  source                                              = "./modules/oke_add_ons/cluster_autoscaler/deployment/enhanced_cluster_addon"
  cluster_id                                          = oci_containerengine_cluster.oci_oke_cluster.id
  autoscaler_pool_settings                            = local.node_pool_list
  cluster_autoscaler_use_workload_identity            = true #var.cluster_autoscaler_use_workload_identity
  cluster_autoscaler_max_node_provision_time          = var.cluster_autoscaler_max_node_provision_time
  cluster_autoscaler_scale_down_delay_after_add       = var.cluster_autoscaler_scale_down_delay_after_add
  cluster_autoscaler_scale_down_unneeded_time         = var.cluster_autoscaler_scale_down_unneeded_time
  cluster_autoscaler_unremovable_node_recheck_timeout = var.cluster_autoscaler_unremovable_node_recheck_timeout
  addon_version                                       = null # null sets auto-update
  depends_on = [
    data.oci_containerengine_cluster_kube_config.oke,
    oci_containerengine_node_pool.oci_oke_node_pool
  ]
}
