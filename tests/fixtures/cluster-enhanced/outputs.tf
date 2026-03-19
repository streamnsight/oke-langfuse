output "cluster_id" {
  value = oci_containerengine_cluster.enhanced.id
}

output "cluster_name" {
  value = oci_containerengine_cluster.enhanced.name
}

output "cluster_type" {
  value = oci_containerengine_cluster.enhanced.type
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.primary.id
}

output "node_pool_size" {
  value = var.node_pool_size
}

output "use_custom_cloud_init" {
  value = var.use_custom_cloud_init
}

output "node_pool_subnet_id" {
  value = data.terraform_remote_state.network.outputs.node_pool_subnet_ids_by_name["np1"]
}

output "bastion_id" {
  value = try(module.bastion[0].id, null)
}

output "network" {
  value = {
    vcn_id                        = data.terraform_remote_state.network.outputs.vcn_id
    kubernetes_endpoint_subnet_id = data.terraform_remote_state.network.outputs.kubernetes_endpoint_subnet_id
    public_lb_subnet_id           = data.terraform_remote_state.network.outputs.public_lb_subnet_id
  }
}
