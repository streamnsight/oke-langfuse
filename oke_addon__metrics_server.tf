## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  metrics_server_helm_values = {
    "numOfReplicas" = 2
  }
}

# Deployment method for a public or private endpoint cluster when 
# it is an enhanced cluster.
# This method uses the cluster add-on resource for enhanced clusters
module "metrics_server_deployment_with_addon_manager" {
  #TODO set flag for deploy metrics server
  count         = (local.enable_metrics_server && local.use_addon_manager) ? 1 : 0
  source        = "./modules/oke/cluster_addons/metrics_server/deployment/enhanced_cluster_addon"
  cluster_id    = local.target_cluster_id
  nb_replicas   = 2
  addon_version = null # null sets auto-update
  enabled       = var.use_existing_cluster ? !contains(local.existing_addons, "KubernetesMetricsServer") : true
  depends_on = [
    module.cert_manager_deployment_using_addon_manager # metrics server depends on cert-manager
  ]
}
