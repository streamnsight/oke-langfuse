locals {
  configurations = {for item in concat([{
    key   = "maxNodeProvisionTime"
    value = "${var.cluster_autoscaler_max_node_provision_time}m"
    }, {
    key   = "scaleDownDelayAfterAdd"
    value = "${var.cluster_autoscaler_scale_down_delay_after_add}m"
    }, {
    key   = "scaleDownUnneededTime"
    value = "${var.cluster_autoscaler_scale_down_unneeded_time}m"
    }, {
    key   = "unremovableNodeRecheckTimeout"
    value = "${var.cluster_autoscaler_unremovable_node_recheck_timeout}m"
    }, {
    key   = "authType"
    value = var.cluster_autoscaler_use_workload_identity ? "workload" : "instance"
    }, {
    key   = "annotations"
    value = "{ \"prometheus.io/scrape\": \"true\", \"prometheus.io/port\": \"8085\" }"
    }, {
    key   = "balanceSimilarNodeGroups"
    value = "true"
    }, {
    key   = "balancingIgnoreLabel"
    value = "displayName,hostname,internal_addr,oci.oraclecloud.com/fault-domain"
    },
    {
    key   = "v"
    value = var.cluster_autoscaler_log_level_verbosity
    }, {
    key   = "nodes"
    value = join(",", [for np in var.autoscaler_pool_settings : "${np.min_nodes}:${np.max_nodes}:${np.id}" if np.autoscale == true])
    }
  ]): item.key => item.value}
}

resource "oci_containerengine_addon" "cluster_autoscaler_addon" {
  count = var.enabled ? 1 : 0
  #Required
  addon_name                       = "ClusterAutoscaler"
  cluster_id                       = var.cluster_id
  remove_addon_resources_on_delete = true


  dynamic "configurations" {
    for_each = local.configurations
    content {
      key   = configurations.key
      value = configurations.value
    }
  }
  version = null # null == auto update
}
