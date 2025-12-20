## Copyright © 2022, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "tls_private_key" "public_private_key_pair" {
  count     = var.ssh_public_key == null ? 1 : 0
  algorithm = "RSA"
}

# The cloud init script module populate scripts that get credentials for nodes to pull 
# images from OCIR.
module "cloud_init_script" {
  source = "./modules/oke/cloud_init_script"
}

# The recommended image module finds the OKE specific image for the generic compute image 
# provided. The OKE specific images have k8s components pre-loaded and is much faster to
# startup, making scale up/down and node cycling events shorter.
module "recommended_image" {
  for_each           = toset([for image in [var.np1_image_id, var.np2_image_id, var.np3_image_id] : image if image != null])
  source             = "./modules/oke/recommended-compute-image"
  image_id           = each.value
  kubernetes_version = local.kubernetes_version
}

# to debug
# output "recommended_images" {
#   value = module.recommended_image
# }

# Checks that requested shapes are available in the requested AD. Some shapes may be 
# available in one AD but not all, and would cause the node-pool to fail when requested 
# to deploy in all ADs. This module provides a map of shape availabilities, used in deploying
# the node pools.
module "available_shapes" {
  source         = "./modules/compute/shape_availability"
  tenancy_ocid   = var.tenancy_ocid
  compartment_id = var.cluster_compartment_id
  wanted_shapes  = compact([var.np1_node_shape, var.np2_node_shape, var.np3_node_shape])
}

locals {
  node_pools = tolist([for node_pool in [
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
      image_id                = module.recommended_image[var.np1_image_id].recommended_image_id
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
      image_id                = module.recommended_image[var.np2_image_id].recommended_image_id
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
      image_id                = module.recommended_image[var.np3_image_id].recommended_image_id
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
  count = length(local.node_pools)

  cluster_id         = oci_containerengine_cluster.oci_oke_cluster.id
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
      for_each = [for ad in local.node_pools[count.index]["ha"] ? module.available_shapes.shape_ad_availability[local.node_pools[count.index]["node_shape"]] : [local.node_pools[count.index]["ad"]] : ad]
      content {
        subnet_id           = var.use_existing_vcn ? local.node_pools[count.index]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id
        availability_domain = placement_configs.value
      }
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
    maximum_unavailable     = 0
  }

  node_metadata = module.cloud_init_script.content

  defined_tags = local.node_pools[count.index]["tags"]

  lifecycle {
    ignore_changes = [
      node_config_details[0].size,
      node_config_details[1].size,
      node_config_details[2].size
    ]
  }
}


# output "cloudinit" {
#   value = module.cloud_init_script.content
# }

