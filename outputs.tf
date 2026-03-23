## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

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

output "integrated_app_name" {
  value = local.cluster_name_sanitized
}

output "test_metadata" {
  description = "Additional non-sensitive metadata for local test tooling when test_mode is enabled."
  value = var.test_mode ? {
    cluster = {
      id             = local.target_cluster_id
      name           = local.target_cluster.name
      compartment_id = local.effective_cluster_compartment_id
      is_existing    = var.use_existing_cluster
    }
    network = {
      vcn_id                        = local.effective_vcn_id
      compartment_id                = local.effective_vcn_compartment_id
      workload_subnet_id            = local.workload_subnet_id
      kubernetes_endpoint_subnet_id = local.effective_cluster_endpoint_subnet_id
    }
    bastion = {
      enabled = length(module.bastion) > 0
      id      = try(module.bastion[0].id, null)
    }
    deployment = {
      deploy_id    = local.deploy_id
      namespace    = "langfuse"
      langfuse_url = "https://${local.langfuse_url}/langfuse"
    }
    gateway = {
      load_balancer_id = module.langfuse_gateway.load_balancer_ocid
      ip_address       = module.langfuse_gateway.ip_address
    }
    devops = {
      project_id     = module.devops_setup.project_id
      environment_id = module.devops_target_cluster_env.environment_id
      pipeline_ids = {
        builder_setup        = module.builder_setup_shell_stage.pipeline_id
        builder_terminate    = module.builder_terminate_shell_stage.pipeline_id
        build_langfuse_image = module.build_langfuse_image.pipeline_id
        langfuse_gateway     = module.langfuse_gateway.pipeline_id
        langfuse_chart       = module.langfuse_chart.pipeline_id
        oci_genai_gateway    = try(module.oci_genai_gateway.pipeline_id, null)
      }
      deployment_ids = {
        builder_setup        = module.builder_setup_shell_stage.deployment_id
        builder_terminate    = module.builder_terminate_shell_stage.deployment_id
        build_langfuse_image = module.build_langfuse_image.deployment_id
        langfuse_gateway     = module.langfuse_gateway.deployment_id
        langfuse_chart       = module.langfuse_chart.deployment_id
        oci_genai_gateway    = try(module.oci_genai_gateway.deployment_id, null)
      }
    }
    registry = {
      compartment_id    = var.devops_compartment_id
      region            = var.region
      tenancy_namespace = data.oci_objectstorage_namespace.ns.namespace
      repositories = {
        langfuse          = "${local.deploy_id}/langfuse"
        oci_genai_gateway = var.enable_oci_genai_gateway ? "${local.deploy_id}/oci-genai-gateway" : null
      }
    }
    vulnerability_scanning = {
      recipe_id    = module.vulnerability_scanning.container_scan_recipe_id
      target_id    = module.vulnerability_scanning.container_scan_target_id
      repositories = local.vulnerability_scanning_repos
    }
    features = {
      oci_genai_gateway_enabled = var.enable_oci_genai_gateway
    }
    existing_cluster_preflight = var.use_existing_cluster && var.enable_existing_cluster_cloud_init_preflight ? {
      compatible             = length(local.existing_cluster_cloud_init_matching_node_pools) > 0
      matching_node_pool_ids = local.existing_cluster_cloud_init_matching_node_pools
      required_markers       = var.existing_cluster_cloud_init_required_markers
    } : null
  } : null
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
