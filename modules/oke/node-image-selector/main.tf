## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  image_id_override_normalized = try(trimspace(var.image_id_override), "") != "" ? trimspace(var.image_id_override) : null
  kubernetes_version_trimmed   = trimprefix(var.kubernetes_version, "v")
  operating_system_slug        = replace(var.operating_system, " ", "-")
  source_name_prefix           = "${local.operating_system_slug}-${var.operating_system_version}"
  shape_is_arm                 = length(regexall("(^|\\.)A1\\.|Ampere", var.shape)) > 0
  shape_is_gpu                 = length(regexall("GPU", var.shape)) > 0
}

data "oci_containerengine_node_pool_option" "oke_node_pool_option" {
  count               = local.image_id_override_normalized == null ? 1 : 0
  node_pool_option_id = "all"
}

locals {
  compatible_sources = local.image_id_override_normalized == null ? [
    for source in try(data.oci_containerengine_node_pool_option.oke_node_pool_option[0].sources, []) :
    source if startswith(source.source_name, local.source_name_prefix) && (
      local.shape_is_arm ? strcontains(source.source_name, "-aarch64-") :
      local.shape_is_gpu ? strcontains(source.source_name, "-GPU-") :
      !strcontains(source.source_name, "-aarch64-") && !strcontains(source.source_name, "-GPU-")
    )
  ] : []

  base_image_candidates = [
    for source in local.compatible_sources : {
      id           = source.image_id
      display_name = source.source_name
    } if !strcontains(source.source_name, "-OKE-")
  ]

  oke_image_candidates = [
    for source in local.compatible_sources : {
      image_id    = source.image_id
      source_name = source.source_name
    } if strcontains(source.source_name, "-OKE-${local.kubernetes_version_trimmed}-")
  ]

  latest_oke_image_sort_key = length(local.oke_image_candidates) > 0 ? reverse(sort([
    for candidate in local.oke_image_candidates :
    "${data.oci_core_image.oke_candidate[candidate.image_id].time_created}|${candidate.image_id}"
  ]))[0] : null

  selected_oke_image = local.latest_oke_image_sort_key == null ? null : one([
    for candidate in local.oke_image_candidates : {
      image_id     = candidate.image_id
      source_name  = candidate.source_name
      display_name = data.oci_core_image.oke_candidate[candidate.image_id].display_name
      time_created = data.oci_core_image.oke_candidate[candidate.image_id].time_created
    } if "${data.oci_core_image.oke_candidate[candidate.image_id].time_created}|${candidate.image_id}" == local.latest_oke_image_sort_key
  ])

  selected_base_image = local.selected_oke_image != null ? {
    id = one([
      for source in local.base_image_candidates :
      source.id if startswith(local.selected_oke_image.source_name, "${source.display_name}-OKE-")
    ])
    display_name = one([
      for source in local.base_image_candidates :
      source.display_name if startswith(local.selected_oke_image.source_name, "${source.display_name}-OKE-")
    ])
  } : null

  selected_image_id = local.image_id_override_normalized != null ? local.image_id_override_normalized : (
    try(local.selected_oke_image.image_id, null)
  )
  selected_source_name = local.image_id_override_normalized != null ? null : (
    try(local.selected_oke_image.source_name, null)
  )
}

data "oci_core_image" "oke_candidate" {
  for_each = {
    for candidate in local.oke_image_candidates :
    candidate.image_id => candidate
  }

  image_id = each.key
}

data "oci_core_image" "selected_image" {
  count    = local.selected_image_id != null ? 1 : 0
  image_id = local.selected_image_id
}

resource "terraform_data" "selector_guard" {
  input = local.selected_image_id

  lifecycle {
    precondition {
      condition     = local.image_id_override_normalized != null || length(local.base_image_candidates) > 0
      error_message = "No compatible base image was found for the requested operating system, operating system version, and shape."
    }

    precondition {
      condition     = local.image_id_override_normalized != null || length(local.oke_image_candidates) > 0
      error_message = "No OKE-ready image was found for the requested operating system, operating system version, shape, and Kubernetes version."
    }
  }
}

output "selected_image_id" {
  value = local.selected_image_id
}

output "selector" {
  value = {
    image_id_override        = local.image_id_override_normalized
    operating_system         = var.operating_system
    operating_system_version = var.operating_system_version
    shape                    = var.shape
    kubernetes_version       = var.kubernetes_version
    base_image_id            = try(local.selected_base_image.id, null)
    base_image_display_name  = try(local.selected_base_image.display_name, null)
    selected_image_id        = local.selected_image_id
    selected_image_name      = try(data.oci_core_image.selected_image[0].display_name, null)
    selected_source_name     = local.selected_source_name
    selected_image_created   = try(local.selected_oke_image.time_created, try(data.oci_core_image.selected_image[0].time_created, null))
  }
}
