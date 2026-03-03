## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  configurations = [{
    key   = "numOfReplicas"
    value = var.nb_replicas
    },
    {
      key   = "compartmentId"
      value = var.compartment_id
    },
    {
      key   = "loadBalancerSubnetId"
      value = var.load_balancers_subnet_id
    },
    {
      key   = "authType"
      value = "workloadIdentity"
    },
    {
      key   = "logVerbosity"
      value = "2"
    },

  ]
}
resource "oci_containerengine_addon" "native_ingress_addon" {
  count = var.enabled ? 1 : 0
  #Required
  addon_name                       = "NativeIngressController"
  cluster_id                       = var.cluster_id
  remove_addon_resources_on_delete = true

  dynamic "configurations" {
    for_each = local.configurations
    content {
      key   = configurations.value.key
      value = configurations.value.value
    }
  }
  version = null
}
