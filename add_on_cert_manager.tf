## Copyright © 2022-2026, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# https://github.com/jetstack/cert-manager/blob/master/README.md
# https://artifacthub.io/packages/helm/cert-manager/cert-manager

locals {
  cert_manager_helm_values = {
    "installCRDs"            = true
    "webhook.timeoutSeconds" = "30"
    "replicaCount"           = var.cert_manager_nb_replicas
  }
}

module "cert_manager_deployment_using_addon_manager" {
  # count                = local.enable_cert_manager ? (local.use_addon_manager ? 1 : 0) : 0
  source               = "./modules/oke_add_ons/cert-manager/deployment/enhanced_cluster_addon"
  cluster_id           = oci_containerengine_cluster.oci_oke_cluster.id
  cert_manager_version = null # for auto-update
  nb_replicas          = var.cert_manager_nb_replicas
  depends_on = [
    data.oci_containerengine_cluster_kube_config.oke,
    oci_containerengine_cluster.oci_oke_cluster,
    oci_containerengine_node_pool.oci_oke_node_pool,
  ]
}
