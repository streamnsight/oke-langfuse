## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  kubernetes_version     = var.use_existing_cluster ? null : "v${module.kubernetes_version[0].versions.selected}"
  cluster_name           = "${substr(var.cluster_name, 0, 200)}-${random_string.deploy_id.result}"
  cluster_name_sanitized = replace(local.cluster_name, " ", "_")
  existing_cluster_worker_subnet_id = var.use_existing_cluster ? try(
    local.existing_cluster_primary_node_pool.node_config_details[0].placement_configs[0].subnet_id,
    local.existing_cluster_primary_node_pool.subnet_ids[0],
    local.existing_cluster_primary_node_pool.nodes[0].subnet_id,
    null
  ) : null

  effective_cluster_compartment_id = data.oci_containerengine_cluster.target.compartment_id

  workload_subnet_id = var.use_existing_cluster ? local.existing_cluster_worker_subnet_id : (var.use_existing_vcn ? local.node_pools[0]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id)

  effective_vcn_id = var.use_existing_cluster ? data.oci_core_subnet.existing_cluster_worker_subnet[0].vcn_id : (var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id)
  effective_vcn_compartment_id = var.use_existing_cluster ? data.oci_core_subnet.existing_cluster_worker_subnet[0].compartment_id : var.vcn_compartment_id
}
