# Copyright (c) 2021, 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

data "oci_core_image" "image" {
  image_id = var.image_id
}

# data "oci_core_image_shapes" "test_image_shapes" {
#     #Required
#     image_id = oci_core_image.test_image.id
# }

data "oci_containerengine_node_pool_option" "oci_oke_node_pool_option" {
  node_pool_option_id = "all"
}

locals {
  k8s_version = replace(var.kubernetes_version, "v", "")
  image_is_valid = length([for option in
    data.oci_containerengine_node_pool_option.oci_oke_node_pool_option.sources :
    option if option.image_id == var.image_id
  ]) > 0
  oke_image = [for option
    in data.oci_containerengine_node_pool_option.oci_oke_node_pool_option.sources :
    option if length(regexall("${data.oci_core_image.image.display_name}-OKE-${local.k8s_version}", option.source_name)) > 0
  ]
  oke_image_id = length(local.oke_image) > 0 ? local.oke_image[0].image_id : local.image_is_valid ? var.image_id : "The image ocid is not compatible"
}

output "recommended_image_id" {
  value = local.oke_image_id
}

output "image_options" {
  value = data.oci_containerengine_node_pool_option.oci_oke_node_pool_option.sources
}

output "images" {
  value = data.oci_core_image.image
}