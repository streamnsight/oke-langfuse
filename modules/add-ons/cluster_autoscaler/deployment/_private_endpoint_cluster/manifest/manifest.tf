# Copyright (c) 2021, 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.


locals {
  cluster_autoscaler_max_node_provision_time          = "${var.cluster_autoscaler_max_node_provision_time}m"
  cluster_autoscaler_scale_down_delay_after_add       = "${var.cluster_autoscaler_scale_down_delay_after_add}m"
  cluster_autoscaler_scale_down_unneeded_time         = "${var.cluster_autoscaler_scale_down_unneeded_time}m"
  cluster_autoscaler_unremovable_node_recheck_timeout = "${var.cluster_autoscaler_unremovable_node_recheck_timeout}m"
  nodes                                               = [for k, v in var.autoscaler_pool_settings : try(lookup(v, "autoscale", false), false) ? "--nodes=${try(lookup(v, "min_nodes", 0), 0)}:${try(lookup(v, "max_nodes", 499), 499)}:${try(lookup(v, "id", ""), "")}" : ""]
  env_dyngroup                                        = file("${path.module}/env-dynamic-group.tmpl.yaml")
  env_workload_id = var.cluster_autoscaler_use_workload_identity ? templatefile("${path.module}/env-workload-identity.tmpl.yaml", {
    region         = var.region
    compartment_id = var.compartment_id
  }) : null
  manifest_yaml = templatefile("${path.module}/cluster-autoscaler.tmpl.yaml", {
    image          = var.image
    compartment_id = var.compartment_id
    region         = var.region
    env            = indent(10, var.cluster_autoscaler_use_workload_identity ? local.env_workload_id : local.env_dyngroup)
    command = indent(10, yamlencode(compact(flatten([
      "./cluster-autoscaler",
      "--v=${var.cluster_autoscaler_log_level_verbosity}",
      "--stderrthreshold=info",
      "--cloud-provider=${var.cloud_provider}",
      "--max-node-provision-time=${local.cluster_autoscaler_max_node_provision_time}",
      local.nodes,
      "--scale-down-delay-after-add=${local.cluster_autoscaler_scale_down_delay_after_add}",
      "--scale-down-unneeded-time=${local.cluster_autoscaler_scale_down_unneeded_time}",
      "--unremovable-node-recheck-timeout=${local.cluster_autoscaler_unremovable_node_recheck_timeout}",
      "--balance-similar-node-groups",
      "--balancing-ignore-label=displayName",
      "--balancing-ignore-label=hostname",
      "--balancing-ignore-label=internal_addr",
      "--balancing-ignore-label=oci.oraclecloud.com/fault-domain"
    ]))))
  })
}
