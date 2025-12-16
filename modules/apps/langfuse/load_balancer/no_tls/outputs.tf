locals {
  lb = [for lb in data.oci_load_balancer_load_balancers.load_balancers.load_balancers : lb.ip_addresses[0]
  if lb.defined_tags["Oracle-Tags.CreatedBy"] == var.cluster_id]
  # && lb.freeform_tags["source"] == "langfuse"]
}

output "ip_address" {
  value = local.lb[0]
}