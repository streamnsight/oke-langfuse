## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

module "kubernetes_version" {
  count = var.use_existing_cluster ? 0 : 1
  # selects closest supported k8s version, or latest version if not defined
  source             = "./modules/oke/kubernetes_version_utils"
  kubernetes_version = var.kubernetes_version
}

resource "oci_containerengine_cluster" "oci_oke_cluster" {
  count = var.use_existing_cluster ? 0 : 1
  # depends_on = [oci_identity_policy.oke_key_access_policy]

  compartment_id = var.cluster_compartment_id
  # default to latest version if kubernetes_version is null
  kubernetes_version = local.kubernetes_version
  name               = local.cluster_name
  vcn_id             = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.oke_vcn[0].id

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  endpoint_config {
    is_public_ip_enabled = var.is_endpoint_public
    subnet_id            = var.use_existing_vcn ? var.kubernetes_endpoint_subnet : oci_core_subnet.oke_api_endpoint_subnet[0].id
  }

  image_policy_config {
    is_policy_enabled = var.enable_image_validation
    dynamic "key_details" {
      for_each = var.enable_image_validation ? [1] : []
      content {
        kms_key_id = var.image_validation_key_id
      }
    }
  }

  kms_key_id = var.enable_secret_encryption ? var.secrets_key_id : null

  options {
    # service_lb_subnet_ids = var.use_existing_vcn ? [for k, v in zipmap([var.public_lb_subnet, var.private_lb_subnet], [var.allow_deploy_public_lb, var.allow_deploy_private_lb]) : k if v] : [for k, v in zipmap([oci_core_subnet.oke_public_lb_subnet[0].id, oci_core_subnet.oke_private_lb_subnet[0].id], [var.allow_deploy_public_lb, var.allow_deploy_private_lb]) : k if v]
    service_lb_subnet_ids = var.use_existing_vcn ? [var.public_lb_subnet] : [oci_core_subnet.oke_lb_subnet[0].id]

    add_ons {
      is_kubernetes_dashboard_enabled = var.cluster_options_add_ons_is_kubernetes_dashboard_enabled
      is_tiller_enabled               = var.cluster_options_add_ons_is_tiller_enabled
    }

    admission_controller_options {
      is_pod_security_policy_enabled = var.enable_pod_admission_controller
    }

    kubernetes_network_config {
      pods_cidr     = var.pods_cidr
      services_cidr = var.services_cidr
    }

    persistent_volume_config {
      defined_tags = var.cluster_tags
    }
    service_lb_config {
      defined_tags = var.cluster_tags
    }

  }
  type         = var.is_enhanced_cluster ? "ENHANCED_CLUSTER" : "BASIC_CLUSTER"
  defined_tags = var.cluster_tags

}

locals {
  target_cluster_id = var.use_existing_cluster ? var.cluster_ocid : oci_containerengine_cluster.oci_oke_cluster[0].id
}

check "existing_cluster_requires_cluster_ocid" {
  assert {
    condition     = !var.use_existing_cluster || (var.cluster_ocid != null && var.cluster_ocid != "")
    error_message = "When use_existing_cluster is true, cluster_ocid must be provided and non-empty."
  }
}

check "existing_cluster_cloud_init_preflight" {
  assert {
    condition     = !var.use_existing_cluster || !var.enable_existing_cluster_cloud_init_preflight || length(local.existing_cluster_cloud_init_matching_node_pools) > 0
    error_message = "When enable_existing_cluster_cloud_init_preflight is true, at least one existing node pool must expose custom cloud-init metadata containing the expected OCIR bootstrap markers. By default this checks for the stack's docker login and credential-helper bootstrap paths inside node_metadata.user_data."
  }
}

data "oci_containerengine_cluster" "target" {
  cluster_id = local.target_cluster_id

  lifecycle {
    postcondition {
      condition     = !var.use_existing_cluster || self.type == "ENHANCED_CLUSTER"
      error_message = "When use_existing_cluster is true, the target cluster must be an ENHANCED_CLUSTER."
    }
    postcondition {
      condition     = !var.use_existing_cluster || self.endpoint_config[0].is_public_ip_enabled == false
      error_message = "When use_existing_cluster is true, the target cluster must expose a private endpoint (is_public_ip_enabled must be false)."
    }
  }
}

resource "terraform_data" "managed_cluster_version_guard" {
  count = var.use_existing_cluster ? 0 : 1
  input = local.target_cluster_id

  lifecycle {
    precondition {
      condition     = local.managed_cluster_live_version_normalized == null || local.managed_cluster_version_is_pinned
      error_message = "This stack already manages an OKE cluster, so kubernetes_version must be explicitly pinned in terraform.tfvars before re-running. Leaving kubernetes_version unset would make the stack follow the moving latest supported version and can create false drift. Set kubernetes_version to the live cluster version (${data.oci_containerengine_cluster.target.kubernetes_version}) or to an intentional upgrade target."
    }

    precondition {
      condition     = local.managed_cluster_live_version_normalized == null || local.managed_cluster_live_version_normalized == local.expected_managed_cluster_version_normalized
      error_message = "The stack-managed OKE cluster is running Kubernetes version ${data.oci_containerengine_cluster.target.kubernetes_version}, but Terraform is configured for ${local.kubernetes_version}. This usually means the cluster was upgraded outside Terraform. Update kubernetes_version in terraform.tfvars to ${data.oci_containerengine_cluster.target.kubernetes_version} before re-running, or intentionally set a different supported target version if you want Terraform to manage another upgrade."
    }
  }
}

data "oci_containerengine_node_pools" "target" {
  cluster_id     = local.target_cluster_id
  compartment_id = var.cluster_compartment_id

  lifecycle {
    postcondition {
      condition = !var.use_existing_cluster || anytrue([
        for node_pool in self.node_pools :
        try(node_pool.node_config_details[0].size, 0) >= 3
      ])
      error_message = "When use_existing_cluster is true, the target cluster must contain at least one existing node pool with 3 or more nodes to support distributed DB resources."
    }
    postcondition {
      condition = !var.use_existing_cluster || anytrue([
        for node_pool in self.node_pools :
        (
          length(try(node_pool.node_config_details[0].placement_configs[0].subnet_id, [])) > 0 ||
          length(try(node_pool.node_config_details[0].subnet_id, [])) > 0 ||
          length(try(node_pool.node_config_details[0].node_pool_pod_network_option_details.pod_subnet_ids, [])) > 0
        )
      ])
      error_message = "When use_existing_cluster is true, at least one existing node pool must expose subnet metadata (placement_configs, subnet_ids, or node subnet_id)."
    }
  }
}

data "oci_containerengine_node_pool" "target" {
  for_each = var.use_existing_cluster && var.enable_existing_cluster_cloud_init_preflight ? {
    for node_pool in local.existing_cluster_sized_node_pools :
    node_pool.id => node_pool
  } : {}

  node_pool_id = each.key
}

data "oci_containerengine_addons" "target" {
  cluster_id = local.target_cluster_id
}


# output add_ons {
#   value = data.oci_containerengine_addons.target
# }

locals {
  managed_cluster_version_is_pinned            = var.use_existing_cluster ? true : (var.kubernetes_version != null && trimspace(var.kubernetes_version) != "")
  requested_managed_cluster_version_normalized = var.use_existing_cluster || !local.managed_cluster_version_is_pinned ? null : replace(var.kubernetes_version, "v", "")
  expected_managed_cluster_version_normalized  = var.use_existing_cluster ? null : replace(local.kubernetes_version, "v", "")
  managed_cluster_live_version_normalized      = var.use_existing_cluster ? null : try(replace(data.oci_containerengine_cluster.target.kubernetes_version, "v", ""), null)
  target_cluster = {
    id              = data.oci_containerengine_cluster.target.id
    name            = data.oci_containerengine_cluster.target.name
    endpoint_config = data.oci_containerengine_cluster.target.endpoint_config
  }

  effective_cluster_endpoint_subnet_id = local.target_cluster.endpoint_config[0].subnet_id

  existing_cluster_sized_node_pools = [
    for node_pool in data.oci_containerengine_node_pools.target.node_pools : node_pool
    if try(node_pool.node_config_details[0].size, 0) >= 3
  ]

  existing_cluster_primary_node_pool = length(local.existing_cluster_sized_node_pools) > 0 ? local.existing_cluster_sized_node_pools[0] : null
  existing_cluster_cloud_init_inspected_node_pool_ids = sort(keys(data.oci_containerengine_node_pool.target))
  existing_cluster_cloud_init_user_data_by_node_pool_id = {
    for node_pool_id, node_pool in data.oci_containerengine_node_pool.target :
    node_pool_id => try(
      base64decode(lookup(try(node_pool.node_metadata, {}), "user_data", "")),
      ""
    )
  }
  existing_cluster_cloud_init_missing_markers_by_node_pool_id = {
    for node_pool_id, user_data in local.existing_cluster_cloud_init_user_data_by_node_pool_id :
    node_pool_id => [
      for marker in var.existing_cluster_cloud_init_required_markers :
      marker if !strcontains(user_data, marker)
    ]
  }
  existing_cluster_cloud_init_matching_node_pools = sort([
    for node_pool_id, missing_markers in local.existing_cluster_cloud_init_missing_markers_by_node_pool_id :
    node_pool_id if length(missing_markers) == 0
  ])

  effective_builder_shape    = var.use_existing_cluster ? try(local.existing_cluster_primary_node_pool.node_shape, var.np1_node_shape) : local.node_pools[0].node_shape
  effective_builder_image_id = var.use_existing_cluster ? try(local.existing_cluster_primary_node_pool.node_source_details[0].image_id, var.np1_image_id) : local.node_pools[0].image_id

  existing_addons = toset([
    for addon in data.oci_containerengine_addons.target.addons : addon.addon_name
    if contains(["ACTIVE", "CREATING", "UPDATING"], addon.state)
  ])
}

# Gets kubeconfig
data "oci_containerengine_cluster_kube_config" "oke" {
  cluster_id = local.target_cluster_id
}
