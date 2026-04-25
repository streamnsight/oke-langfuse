output "cluster_id" {
  value = oci_containerengine_cluster.basic.id
}

output "cluster_name" {
  value = oci_containerengine_cluster.basic.name
}

output "cluster_type" {
  value = oci_containerengine_cluster.basic.type
}

output "network" {
  value = {
    vcn_id                        = data.terraform_remote_state.network.outputs.vcn_id
    kubernetes_endpoint_subnet_id = data.terraform_remote_state.network.outputs.kubernetes_endpoint_subnet_id
    public_lb_subnet_id           = data.terraform_remote_state.network.outputs.public_lb_subnet_id
  }
}
