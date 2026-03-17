# ## Copyright © 2022-2026, Oracle and/or its affiliates.
# ## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# locals {
#   native_ingress_helm_values = {
#     "installCRDs"            = true
#     "webhook.timeoutSeconds" = "30"
#     "replicaCount"           = 1
#   }
# }

# module "native_ingress_deployment_using_addon_manager" {
#   count                    = local.use_addon_manager && !contains(local.existing_addons, "NativeIngressController") ? 1 : 0
#   source                   = "./modules/oke/cluster_addons/native_ingress/deployment/enhanced_cluster_addon"
#   cluster_id               = local.target_cluster_id
#   nb_replicas              = 1
#   load_balancers_subnet_id = var.use_existing_cluster ? data.oci_containerengine_cluster.target.endpoint_config[0].subnet_id : (var.use_existing_vcn ? var.public_lb_subnet : oci_core_subnet.oke_lb_subnet[0].id)
#   compartment_id           = var.vcn_compartment_id
# }

# module "native_ingress_workload_identity_policy" {
#   source               = "./modules/iam/workload_identity"
#   compartment_id       = var.cluster_compartment_id
#   workload_name        = "oci-native-ingress-controller"
#   service_account_name = "oci-native-ingress-controller"
#   namespace            = "native-ingress-controller-system"
#   permissions = [
#     "manage load-balancers",
#     "use virtual-network-family",
#     "manage cabundles",
#     "manage cabundle-associations",
#     "manage leaf-certificates",
#     "read leaf-certificate-bundles",
#     "manage leaf-certificate-versions",
#     "manage certificate-associations",
#     "read certificate-authorities",
#     "manage certificate-authority-associations",
#     "read certificate-authority-bundles",
#     "read public-ips",
#     "manage floating-ips",
#     "manage waf-family",
#     "read cluster-family",
#     "use tag-namespaces"
#   ]
#   defined_tags = var.defined_tags
#   cluster_id   = local.target_cluster_id
#   providers = {
#     oci = oci.home_region
#   }
#   depends_on = [
#     module.cert_manager_deployment_using_addon_manager # metrics server depends on cert-manager
#   ]
# }
