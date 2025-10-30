data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

data "oci_limits_limit_definitions" "limit_def" {
  compartment_id = var.tenancy_ocid
  service_name   = "compute"
}

data "oci_core_shapes" "valid_shapes" {
  count               = length(data.oci_identity_availability_domains.ADs.availability_domains)
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[count.index].name
}
