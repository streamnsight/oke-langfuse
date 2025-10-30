resource "oci_identity_policy" "policy" {
  #Required
  compartment_id = var.compartment_id
  description    = var.description
  name           = lower(replace(var.description, " ", "_"))
  statements     = var.policy_statements
}