# ## Copyright © 2022, Oracle and/or its affiliates. 
# ## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# # output "cluster" {
# #   value = {
# #     id                 = oci_containerengine_cluster.oci_oke_cluster.id
# #     kubernetes_version = oci_containerengine_cluster.oci_oke_cluster.kubernetes_version
# #     name               = oci_containerengine_cluster.oci_oke_cluster.name
# #   }
# # }

# # output "node_pool" {
# #   value = {
# #     id                 = oci_containerengine_node_pool.oci_oke_node_pool.id
# #     kubernetes_version = oci_containerengine_node_pool.oci_oke_node_pool.kubernetes_version
# #     name               = oci_containerengine_node_pool.oci_oke_node_pool.name
# #   }
# # }

# output "chosen_node_shape_and_image" {
#   value = {
#     image_id    = element([for source in data.oci_containerengine_node_pool_option.oci_oke_node_pool_option.sources : source.image_id if length(regexall("Oracle-Linux-${var.node_linux_version}-20[0-9]*.*", source.source_name)) > 0], 0)
#     source_name = element([for source in data.oci_containerengine_node_pool_option.oci_oke_node_pool_option.sources : source.source_name if length(regexall("Oracle-Linux-${var.node_linux_version}-20[0-9]*.*", source.source_name)) > 0], 0)
#   }
# }

# # output "KubeConfig" {
# #   value = data.oci_containerengine_cluster_kube_config.KubeConfig.content
# # }

# # output "services" {
# #   value = data.oci_core_services.AllOCIServices
# # }

# # output "k8s" {
# #   value = reverse(data.oci_containerengine_cluster_option.cluster_options.kubernetes_versions)[0]
# # }

# # output "node-options" {
# #   value = data.oci_containerengine_node_pool_option.oci_oke_node_pool_option
# # }

# # output "images" {
# #   value = var.np1_image_id == null ? {
# #     gpu = local.gpu
# #     arm = local.arm
# #     x86 = local.x86
# #   } : {}
# # }

# # # output test_image {
# # #   value = data.oci_core_image_shapes.test_image_shapes
# # # }

# # output "test_cidr" {
# #   value = cidrsubnets("10.0.0.0/16", 15, 4, 4, 4)
# # }

# output "access_command" {
#   value = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.oci_oke_cluster.id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0  --kube-endpoint ${var.is_endpoint_public ? "PUBLIC_ENDPOINT" : "PRIVATE_ENDPOINT"}"
# }

# output "cluster_id" {
#   value = oci_containerengine_cluster.oci_oke_cluster.id
# }

output "cluster_name" {
  value = local.cluster_name
}

# output "img" {
#   value = module.recommended_image
# }

# output "k8s_version" {
#   value = local.kubernetes_version
# }

# output "k8s_versions_full" {
#   value = module.kubernetes_version.versions
# }