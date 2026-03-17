## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# defines trigger to enable specific components based on selection
locals {
  enable_cert_manager       = var.enable_cert_manager
  enable_cluster_autoscaler = !var.use_existing_cluster && (var.np1_enable_autoscaler || var.np2_enable_autoscaler || var.np3_enable_autoscaler)
  enable_metrics_server     = var.enable_metrics_server
}

# Define what deployment method will be used depending on the cluster type and k8s endpoint access
locals {
  any_addon_enabled = local.enable_cert_manager || local.enable_cluster_autoscaler || local.enable_metrics_server
  # enhanced clusters use add-on manager
  use_addon_manager = var.use_existing_cluster ? data.oci_containerengine_cluster.target.type == "ENHANCED_CLUSTER" : var.is_enhanced_cluster

  object_storage_namespace = var.object_storage_namespace == null ? data.oci_objectstorage_namespace.ns.namespace : var.object_storage_namespace
}

# Setup the DevOps project when using DevOps
module "devops_setup" {
  source         = "./modules/devops/project"
  compartment_id = var.devops_compartment_id
  project_name   = "${local.cluster_name}-deployments"
  target_cluster = local.target_cluster
  defined_tags   = var.defined_tags
}

# Setup the DevOps project cluster environment when using DevOps
module "devops_target_cluster_env" {
  source         = "./modules/devops/environment"
  project_id     = module.devops_setup.project_id
  target_cluster = local.target_cluster
  defined_tags   = var.defined_tags
}

# Create policies for the DevOps service to do its work.
module "devops_policies" {
  source                             = "./modules/devops/policies"
  devops_compartment_id              = var.devops_compartment_id
  vcn_compartment_id                 = var.vcn_compartment_id
  cluster_compartment_id             = var.cluster_compartment_id
  secrets_store_vault_compartment_id = var.secrets_store_vault_compartment_id
  cluster_name                       = local.cluster_name_sanitized
  providers = {
    oci = oci.home_region
  }
}
