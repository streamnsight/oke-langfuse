## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "tls_private_key" "public_private_key_pair" {
  count     = var.use_existing_cluster ? 0 : (var.ssh_public_key == null ? 1 : 0)
  algorithm = "RSA"
}

# The cloud init script module populate scripts that get credentials for nodes to pull 
# images from OCIR.
module "cloud_init_script" {
  count  = var.use_existing_cluster ? 0 : 1
  source = "./modules/oke/cloud_init_script"
}

# Checks that requested shapes are available in the requested AD. Some shapes may be 
# available in one AD but not all, and would cause the node-pool to fail when requested 
# to deploy in all ADs. This module provides a map of shape availabilities, used in deploying
# the node pools.
module "available_shapes" {
  count          = var.use_existing_cluster ? 0 : 1
  source         = "./modules/compute/shape_availability"
  tenancy_ocid   = var.tenancy_ocid
  compartment_id = var.cluster_compartment_id
  wanted_shapes  = compact([var.np1_node_shape, var.np2_node_shape, var.np3_node_shape])
}

module "np1_node_image_selector" {
  count                    = var.use_existing_cluster || var.node_pool_count < 1 || var.np1_image_override ? 0 : 1
  source                   = "./modules/oke/node-image-selector"
  compartment_id           = var.tenancy_ocid
  kubernetes_version       = local.kubernetes_version
  operating_system         = var.np1_operating_system
  operating_system_version = var.np1_operating_system_version
  shape                    = var.np1_node_shape
}

module "np2_node_image_selector" {
  count                    = var.use_existing_cluster || var.node_pool_count < 2 || var.np2_image_override ? 0 : 1
  source                   = "./modules/oke/node-image-selector"
  compartment_id           = var.tenancy_ocid
  kubernetes_version       = local.kubernetes_version
  operating_system         = var.np2_operating_system
  operating_system_version = var.np2_operating_system_version
  shape                    = var.np2_node_shape
}

module "np3_node_image_selector" {
  count                    = var.use_existing_cluster || var.node_pool_count < 3 || var.np3_image_override ? 0 : 1
  source                   = "./modules/oke/node-image-selector"
  compartment_id           = var.tenancy_ocid
  kubernetes_version       = local.kubernetes_version
  operating_system         = var.np3_operating_system
  operating_system_version = var.np3_operating_system_version
  shape                    = var.np3_node_shape
}

resource "terraform_data" "node_pool_image_override_validation" {
  count = var.use_existing_cluster ? 0 : 1

  input = {
    np1_image_override = var.np1_image_override
    np2_image_override = var.np2_image_override
    np3_image_override = var.np3_image_override
  }

  lifecycle {
    precondition {
      condition     = var.node_pool_count < 1 || !var.np1_image_override || try(trimspace(var.np1_image_id), "") != ""
      error_message = "np1_image_override is enabled, so np1_image_id must be set to a non-empty image OCID."
    }

    precondition {
      condition     = var.node_pool_count < 2 || !var.np2_image_override || try(trimspace(var.np2_image_id), "") != ""
      error_message = "np2_image_override is enabled, so np2_image_id must be set to a non-empty image OCID."
    }

    precondition {
      condition     = var.node_pool_count < 3 || !var.np3_image_override || try(trimspace(var.np3_image_id), "") != ""
      error_message = "np3_image_override is enabled, so np3_image_id must be set to a non-empty image OCID."
    }
  }
}

locals {
  node_pool_image_overrides_enabled = var.use_existing_cluster ? {} : {
    np1 = var.node_pool_count >= 1 && var.np1_image_override
    np2 = var.node_pool_count >= 2 && var.np2_image_override
    np3 = var.node_pool_count >= 3 && var.np3_image_override
  }

  node_pool_image_ids_present = var.use_existing_cluster ? {} : {
    np1 = var.node_pool_count >= 1 && try(trimspace(var.np1_image_id), "") != ""
    np2 = var.node_pool_count >= 2 && try(trimspace(var.np2_image_id), "") != ""
    np3 = var.node_pool_count >= 3 && try(trimspace(var.np3_image_id), "") != ""
  }

  node_pool_image_override_status = {
    overrides_enabled  = [for node_pool, enabled in local.node_pool_image_overrides_enabled : node_pool if enabled]
    ignored_image_ids  = [for node_pool, present in local.node_pool_image_ids_present : node_pool if present && !local.node_pool_image_overrides_enabled[node_pool]]
    guidance           = "np*_image_id is ignored unless the matching np*_image_override flag is enabled."
    migration_guidance = "If you upgraded from an older stack version, you may want to clear stale saved np*_image_id values, but they do not affect image selection while override is disabled."
  }
}

locals {
  node_pools = var.use_existing_cluster ? [] : tolist([for node_pool in [
    var.node_pool_count >= 1 ?
    {
      subnet                  = var.use_existing_vcn ? var.np1_subnet : oci_core_subnet.oke_nodepool_subnet[0].id
      ha                      = var.np1_ha
      ad                      = var.np1_availability_domain
      autoscale               = var.np1_enable_autoscaler
      node_count              = var.np1_enable_autoscaler ? var.np1_autoscaler_min_nodes : var.np1_node_count
      min_nodes               = var.np1_autoscaler_min_nodes
      max_nodes               = var.np1_autoscaler_max_nodes
      node_shape              = var.np1_node_shape
      image_id                = var.np1_image_override ? var.np1_image_id : module.np1_node_image_selector[0].selected_image_id
      boot_volume_size_in_gbs = var.np1_boot_volume_size_in_gbs
      tags                    = var.np1_tags
      ocpus                   = var.np1_ocpus
      memory_gb               = var.np1_memory_gb
    } : null,
    var.node_pool_count >= 2 ? {
      subnet                  = var.use_existing_vcn ? var.np2_subnet : var.np2_create_new_subnet ? oci_core_subnet.oke_nodepool_subnet[1].id : oci_core_subnet.oke_nodepool_subnet[0].id
      ha                      = var.np2_ha
      ad                      = var.np2_availability_domain
      autoscale               = var.np2_enable_autoscaler
      node_count              = var.np2_enable_autoscaler ? var.np2_autoscaler_min_nodes : var.np2_node_count
      min_nodes               = var.np2_autoscaler_min_nodes
      max_nodes               = var.np2_autoscaler_max_nodes
      node_shape              = var.np2_node_shape
      image_id                = var.np2_image_override ? var.np2_image_id : module.np2_node_image_selector[0].selected_image_id
      boot_volume_size_in_gbs = var.np2_boot_volume_size_in_gbs
      tags                    = var.np2_tags
      ocpus                   = var.np2_ocpus
      memory_gb               = var.np2_memory_gb
    } : null,
    var.node_pool_count >= 3 ? {
      subnet                  = var.use_existing_vcn ? var.np3_subnet : var.np3_create_new_subnet ? oci_core_subnet.oke_nodepool_subnet[length(oci_core_subnet.oke_nodepool_subnet) - 1].id : oci_core_subnet.oke_nodepool_subnet[0].id
      ha                      = var.np3_ha
      ad                      = var.np3_availability_domain
      autoscale               = var.np3_enable_autoscaler
      node_count              = var.np3_enable_autoscaler ? var.np3_autoscaler_min_nodes : var.np3_node_count
      min_nodes               = var.np3_autoscaler_min_nodes
      max_nodes               = var.np3_autoscaler_max_nodes
      node_shape              = var.np3_node_shape
      image_id                = var.np3_image_override ? var.np3_image_id : module.np3_node_image_selector[0].selected_image_id
      boot_volume_size_in_gbs = var.np3_boot_volume_size_in_gbs
      tags                    = var.np3_tags
      ocpus                   = var.np3_ocpus
      memory_gb               = var.np3_memory_gb
    } : null
  ] : node_pool if node_pool != null])
  # the list below is the same as the above but includes nodepool ids when they become available. It is used for the autoscaler 
  node_pool_list = [for i in range(length(local.node_pools)) : merge(local.node_pools[i], { id = oci_containerengine_node_pool.oci_oke_node_pool[i].id })]
}

resource "oci_containerengine_node_pool" "oci_oke_node_pool" {
  count = var.use_existing_cluster ? 0 : length(local.node_pools)

  cluster_id         = local.target_cluster_id
  compartment_id     = var.cluster_compartment_id
  kubernetes_version = local.kubernetes_version
  name               = "${replace(local.node_pools[count.index]["node_shape"], "Standard", "Std")}${length(regexall("Flex", local.node_pools[count.index]["node_shape"])) > 0 ? "-${local.node_pools[count.index]["ocpus"]}-${local.node_pools[count.index]["memory_gb"]}GB" : ""}"
  node_shape         = local.node_pools[count.index]["node_shape"]

  #   initial_node_labels {
  #     key   = var.node_pool_initial_node_labels_key
  #     value = var.node_pool_initial_node_labels_value
  #   }

  node_source_details {
    image_id                = local.node_pools[count.index]["image_id"]
    source_type             = "IMAGE"
    boot_volume_size_in_gbs = local.node_pools[count.index]["boot_volume_size_in_gbs"]
  }

  ssh_public_key = var.ssh_public_key != null ? var.ssh_public_key : tls_private_key.public_private_key_pair[0].public_key_openssh

  node_config_details {
    dynamic "placement_configs" {
      for_each = [for ad in local.node_pools[count.index]["ha"] ? module.available_shapes[0].shape_ad_availability[local.node_pools[count.index]["node_shape"]] : [local.node_pools[count.index]["ad"]] : ad]
      content {
        subnet_id           = var.use_existing_vcn ? local.node_pools[count.index]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id
        availability_domain = placement_configs.value
      }
    }

    node_pool_pod_network_option_details {
      cni_type       = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids = [var.use_existing_vcn ? local.node_pools[count.index]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id]
    }
    size         = local.node_pools[count.index]["node_count"]
    defined_tags = local.node_pools[count.index]["tags"]
  }

  dynamic "node_shape_config" {
    for_each = length(regexall("Flex", local.node_pools[count.index]["node_shape"])) > 0 ? [1] : []
    content {
      ocpus         = local.node_pools[count.index]["ocpus"]
      memory_in_gbs = local.node_pools[count.index]["memory_gb"]
    }
  }

  node_eviction_node_pool_settings {
    eviction_grace_duration              = "PT10M"
    is_force_delete_after_grace_duration = true
  }

  node_pool_cycling_details {
    is_node_cycling_enabled = true
    maximum_surge           = 1
    maximum_unavailable     = 1
  }

  node_metadata = module.cloud_init_script[0].content

  defined_tags = local.node_pools[count.index]["tags"]

  lifecycle {
    ignore_changes = [
      node_config_details[0].size,
      node_config_details[1].size,
      node_config_details[2].size
    ]
  }

  depends_on = [
    module.policies_before_node_pool
  ]
}


output "cloudinit" {
  value = base64decode(module.cloud_init_script[0].content.user_data)
}

