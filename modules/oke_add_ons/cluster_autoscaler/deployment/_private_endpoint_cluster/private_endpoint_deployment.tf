locals {
  repos = [
    {
      "src_registry"  = "us-ashburn-1.ocir.io",
      "repo"          = "oracle/oci-cluster-autoscaler",
      "dest_registry" = "${var.region}.ocir.io"
      "dest_ns"       = "${var.object_storage_namespace}"
      "dest_repo"     = "${var.oss_images_repo_prefix}/cluster-autoscaler"
      "version"       = "${module.container_image.tag}"
      "source"        = "us-ashburn-1.ocir.io/oracle/oci-cluster-autoscaler"
      "destination"   = "${var.region}.ocir.io/${var.object_storage_namespace}/${var.oss_images_repo_prefix}/cluster-autoscaler"
    }
  ]
  image = "${local.repos[0]["destination"]}:${local.repos[0]["version"]}"
}

module "container_image" {
  source             = "../../image"
  kubernetes_version = var.kubernetes_version
  ocir_region        = "us-ashburn-1"
}

module "manifest" {
  # If we have an enhanced cluster, we can deploy as an add-on and don't need the manifest
  source                                              = "./manifest"
  image                                               = local.image
  compartment_id                                      = var.cluster_compartment_id
  region                                              = var.region
  cluster_autoscaler_use_workload_identity            = var.cluster_autoscaler_use_workload_identity
  autoscaler_pool_settings                            = var.autoscaler_pool_settings
  cloud_provider                                      = module.container_image.ca_provider
  cluster_autoscaler_log_level_verbosity              = var.cluster_autoscaler_log_level_verbosity
  cluster_autoscaler_max_node_provision_time          = var.cluster_autoscaler_max_node_provision_time
  cluster_autoscaler_scale_down_delay_after_add       = var.cluster_autoscaler_scale_down_delay_after_add
  cluster_autoscaler_scale_down_unneeded_time         = var.cluster_autoscaler_scale_down_unneeded_time
  cluster_autoscaler_unremovable_node_recheck_timeout = var.cluster_autoscaler_unremovable_node_recheck_timeout
}

module "push_cluster_autoscaler_image" {
  count                    = var.push_oss_images ? 1 : 0
  source                   = "../../../../devops/ocir/push_image"
  region                   = var.region
  oci_profile              = var.oci_profile
  compartment_id           = var.devops_compartment_id
  object_storage_namespace = var.object_storage_namespace
  oss_images_repo_prefix   = var.oss_images_repo_prefix
  repo                     = local.repos[0]
}


resource "oci_devops_deploy_artifact" "cluster-autoscaler-manifest" {
  argument_substitution_mode = "SUBSTITUTE_PLACEHOLDERS"
  deploy_artifact_source {
    base64encoded_content       = module.manifest.manifest_yaml
    deploy_artifact_source_type = "INLINE"
  }
  deploy_artifact_type = "KUBERNETES_MANIFEST"
  description          = "Cluster Autoscaler manifest"
  display_name         = "cluster-autoscaler-manifest"
  defined_tags         = var.defined_tags
  project_id           = var.devops_project_id
  lifecycle {
    ignore_changes = [defined_tags]
  }
}


resource "oci_devops_deploy_stage" "cluster-autoscaler" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.cluster_autoscaler_add_on.id
  deploy_stage_predecessor_collection {
    items {
      id = oci_devops_deploy_pipeline.cluster_autoscaler_add_on.id
    }
  }
  deploy_stage_type = "OKE_DEPLOYMENT"
  description       = "Deploy Cluster Autoscaler"
  display_name      = "cluster-autoscaler"
  defined_tags      = var.defined_tags
  kubernetes_manifest_deploy_artifact_ids = [
    oci_devops_deploy_artifact.cluster-autoscaler-manifest.id,
  ]
  namespace                         = "kube-system"
  oke_cluster_deploy_environment_id = var.devops_environment_id
  rollback_policy {
    policy_type = "AUTOMATED_STAGE_ROLLBACK_POLICY"
  }
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_devops_deploy_pipeline" "cluster_autoscaler_add_on" {
  # deploy_pipeline_parameters {
  # }
  description  = "Cluster AutoScaler Add-on"
  display_name = "cluster_autoscaler_add_on"
  project_id   = var.devops_project_id
  defined_tags = var.defined_tags
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_devops_deployment" "cluster_autoscaler_deployment" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.cluster_autoscaler_add_on.id
  deployment_type    = "PIPELINE_DEPLOYMENT"
  display_name       = "cluster_autoscaler_add_on"
  defined_tags       = var.defined_tags
  #previous_deployment_id = <<Optional value not found in discovery>>
  trigger_new_devops_deployment = tostring(var.force_deployment)
  depends_on = [
    oci_devops_deploy_stage.cluster-autoscaler,
    module.push_cluster_autoscaler_image,
    oci_devops_deploy_artifact.cluster-autoscaler-manifest
  ]
  lifecycle {
    ignore_changes = [defined_tags]
  }
}
