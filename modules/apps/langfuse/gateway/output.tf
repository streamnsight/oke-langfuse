
data "oci_load_balancer_load_balancers" "load_balancers" {
  #Required
  compartment_id = var.compartment_id

  #Optional
  detail = "full"
  # display_name = "langfuse-web-${local.deploy_id}"

  depends_on = [oci_devops_deployment.langfuse_gateway_deployment]
}


locals {
  lb = [for lb in data.oci_load_balancer_load_balancers.load_balancers.load_balancers : lb
  if lb.defined_tags["Oracle-Tags.CreatedBy"] == var.cluster_id && lookup(lb.freeform_tags, "source", "") == "istio-gateway"]
}

output "ip_address" {
  value = local.lb[0].ip_addresses[0]
}

output "load_balancer_ocid" {
  value = local.lb[0].id
}
