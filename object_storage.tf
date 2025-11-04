
resource "oci_objectstorage_bucket" "traces_bucket" {
  #Required
  compartment_id = var.cluster_compartment_id
  name           = "langfuse-${local.deploy_id}-traces"
  namespace      = data.oci_objectstorage_namespace.ns.namespace

  #Optional
  access_type  = "NoPublicAccess"
  auto_tiering = "InfrequentAccess"
}