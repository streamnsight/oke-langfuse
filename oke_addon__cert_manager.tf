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
  count                = (var.use_existing_cluster ? (local.enable_cert_manager && local.use_addon_manager && !contains(local.existing_addons, "CertManager")) : (local.enable_cert_manager && var.is_enhanced_cluster)) ? 1 : 0
  source               = "./modules/oke/cluster_addons/cert-manager/deployment/enhanced_cluster_addon"
  cluster_id           = local.target_cluster_id
  cert_manager_version = null # for auto-update
  nb_replicas          = var.cert_manager_nb_replicas
  depends_on = [
    data.oci_containerengine_cluster_kube_config.oke
  ]
}
