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

  ]
}
resource "oci_containerengine_addon" "cert_manager_addon" {
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
  version = var.cert_manager_version
}
