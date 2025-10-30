

# build map of valid and available shapes for each AD
locals {
  availability_map = [for def in data.oci_limits_limit_definitions.limit_def.limit_definitions : def if contains(var.wanted_shapes, def.description)]
  limits_definitions = [
    for ad in range(length(data.oci_identity_availability_domains.ADs.availability_domains)) : [
      for shape in data.oci_core_shapes.valid_shapes[ad].shapes : { "${shape.name}" = { "${data.oci_identity_availability_domains.ADs.availability_domains[ad].name}" = shape.quota_names } }
      if contains(var.wanted_shapes, shape.name)
    ]
  ]
  shape_ad_availability = transpose(
    merge([
      for ad in range(length(data.oci_identity_availability_domains.ADs.availability_domains)) : {
        "${data.oci_identity_availability_domains.ADs.availability_domains[ad].name}" = [
          for shape in data.oci_core_shapes.valid_shapes[ad].shapes : "${shape.name}"
          if contains(var.wanted_shapes, shape.name)
        ]
      }
    ]...)
  )
}



output "shape_ad_availability" {
  value = local.shape_ad_availability
}