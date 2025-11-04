## Copyright © 2023, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# defines trigger to enable specific components based on selection
locals {
  enable_cert_manager       = var.enable_cert_manager
  enable_cluster_autoscaler = var.np1_enable_autoscaler || var.np2_enable_autoscaler || var.np3_enable_autoscaler
  enable_metrics_server     = var.enable_metrics_server
}

# Define what deployment method will be used depending on the cluster type and k8s endpoint access
locals {
  any_addon_enabled = local.enable_cert_manager || local.enable_cluster_autoscaler || local.enable_metrics_server
  # enhanced clusters use add-on manager
  use_addon_manager = var.is_enhanced_cluster

  object_storage_namespace = var.object_storage_namespace == null ? data.oci_objectstorage_namespace.ns.namespace : var.object_storage_namespace
}

# Setup the DevOps project when using DevOps
module "devops_setup" {
  source         = "./modules/devops/project"
  compartment_id = var.devops_compartment_id
  project_name   = "${local.cluster_name}-deployments"
  target_cluster = oci_containerengine_cluster.oci_oke_cluster
  defined_tags   = var.defined_tags
}

# Setup the DevOps project cluster environment when using DevOps
module "devops_target_cluster_env" {
  source         = "./modules/devops/environment"
  project_id     = module.devops_setup[0].project_id
  target_cluster = oci_containerengine_cluster.oci_oke_cluster
  defined_tags   = var.defined_tags
}

# Create policies for the DevOps service to do its work.
module "devops_policies" {
  source                 = "./modules/devops/policies"
  devops_compartment_id  = var.devops_compartment_id
  vcn_compartment_id     = var.vcn_compartment_id
  cluster_compartment_id = var.cluster_compartment_id
  cluster_name           = local.cluster_name_sanitized
  providers = {
    oci = oci.home_region
  }
}

## Code repo with build scripts
module "devops_code_repo" {
  source      = "./modules/devops/repository"
  project_id  = module.devops_setup.project_id
  name        = "oke-langfuse"
  description = "Langfuse deployment on OKE"
}

resource "null_resource" "clone_repo" {

  # build and deploy OCI GenAI Gateway
  provisioner "local-exec" {
    command = <<-EOT
    git clone 
    EOT
    # Optional arguments:
    when       = create
    on_failure = fail # or "continue"
    environment = {
      REGION                 = var.region
      CLUSTER_ID             = var.cluster_id
      AUTH_TYPE              = "INSTANCE_PRINCIPAL"
      MODULE_PATH            = "${path.module}"
      BASTION_SESSION_ID     = var.bastion_session_id
      COMPARTMENT_ID         = var.compartment_id
      TENANCY_NAMESPACE      = data.oci_objectstorage_namespace.ns.namespace
      OCI_GENAI_GATEWAY_TAG  = var.oci_genai_gateway_tag
      LANGFUSE_K8S_NAMESPACE = "langfuse"
    }
  }
  depends_on = [
    local_file.sock5_privatekey
  ]
}