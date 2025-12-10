# Copyright © 2022, Oracle and/or its affiliates. 
# All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  native_ingress_helm_values = {
    "installCRDs"            = true
    "webhook.timeoutSeconds" = "30"
    "replicaCount"           = 1
  }
}

module "native_ingress_deployment_using_addon_manager" {
  # count                = local.enable_cert_manager ? (local.use_addon_manager ? 1 : 0) : 0
  source                   = "./modules/oke_add_ons/native_ingress/deployment/enhanced_cluster_addon"
  cluster_id               = oci_containerengine_cluster.oci_oke_cluster.id
  nb_replicas              = 1
  load_balancers_subnet_id = oci_core_subnet.oke_lb_subnet[0].id
  compartment_id           = var.vcn_compartment_id
  depends_on = [
    oci_containerengine_cluster.oci_oke_cluster,
    oci_containerengine_node_pool.oci_oke_node_pool,
  ]
}
