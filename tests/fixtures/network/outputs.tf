output "vcn_id" {
  value = oci_core_vcn.shared.id
}

output "vcn_cidr" {
  value = var.vcn_cidr
}

output "compartment_id" {
  value = var.compartment_id
}

output "kubernetes_endpoint_subnet_id" {
  value = oci_core_subnet.api.id
}

output "public_lb_subnet_id" {
  value = oci_core_subnet.lb.id
}

output "node_pool_subnet_ids" {
  value = [for subnet in sort(values(oci_core_subnet.nodepool)[*].id) : subnet]
}

output "node_pool_subnet_ids_by_name" {
  value = {
    for key, subnet in oci_core_subnet.nodepool :
    "np${tonumber(key) + 1}" => subnet.id
  }
}

output "subnet_ids" {
  value = {
    api       = oci_core_subnet.api.id
    lb        = oci_core_subnet.lb.id
    nodepools = [for subnet in sort(values(oci_core_subnet.nodepool)[*].id) : subnet]
  }
}
