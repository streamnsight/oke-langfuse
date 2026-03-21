## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  image_id_override_normalized = try(trimspace(var.image_id_override), "") != "" ? trimspace(var.image_id_override) : null
  kubernetes_version_trimmed   = trimprefix(var.kubernetes_version, "v")
}

data "oci_core_images" "base_images" {
  count                    = local.image_id_override_normalized == null ? 1 : 0
  compartment_id           = var.compartment_id
  operating_system         = var.operating_system
  operating_system_version = var.operating_system_version
  shape                    = var.shape
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  filter {
    name   = "display_name"
    values = ["^(?!.*-OKE-).*$"]
    regex  = true
  }
}

locals {
  base_image_candidates = local.image_id_override_normalized == null ? try(data.oci_core_images.base_images[0].images, []) : []
  base_image            = length(local.base_image_candidates) > 0 ? local.base_image_candidates[0] : null
}

module "recommended_image" {
  count              = local.image_id_override_normalized == null && local.base_image != null ? 1 : 0
  source             = "../recommended-compute-image"
  image_id           = local.base_image.id
  kubernetes_version = var.kubernetes_version
}

locals {
  oke_image_candidates = local.image_id_override_normalized == null && length(module.recommended_image) > 0 ? [
    for option in module.recommended_image[0].image_options :
    option if startswith(
      option.source_name,
      "${module.recommended_image[0].images.display_name}-OKE-${local.kubernetes_version_trimmed}"
    )
  ] : []

  selected_image_id = local.image_id_override_normalized != null ? local.image_id_override_normalized : (
    length(local.oke_image_candidates) > 0 ? local.oke_image_candidates[0].image_id : null
  )
  selected_source_name = local.image_id_override_normalized != null ? null : (
    length(local.oke_image_candidates) > 0 ? local.oke_image_candidates[0].source_name : null
  )
}

data "oci_core_image" "selected_image" {
  count    = local.selected_image_id != null ? 1 : 0
  image_id = local.selected_image_id
}

resource "terraform_data" "selector_guard" {
  input = local.selected_image_id

  lifecycle {
    precondition {
      condition     = local.image_id_override_normalized != null || local.base_image != null
      error_message = "No compatible base image was found for the requested operating system, operating system version, and shape."
    }

    precondition {
      condition     = local.image_id_override_normalized != null || length(local.oke_image_candidates) > 0
      error_message = "No OKE-ready image was found for the selected base image and requested Kubernetes version."
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
    base_image_id            = try(local.base_image.id, null)
    base_image_display_name  = try(local.base_image.display_name, null)
    selected_image_id        = local.selected_image_id
    selected_image_name      = try(data.oci_core_image.selected_image[0].display_name, null)
    selected_source_name     = local.selected_source_name
  }
}
