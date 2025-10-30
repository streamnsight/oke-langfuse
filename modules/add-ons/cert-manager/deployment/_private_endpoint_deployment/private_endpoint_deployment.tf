# for a private endpoint deployment, several things are required:
# - a DevOps project configured with an environment to connect to the cluster
# - proper permissions for the devops resources to be able to read artifacts and deploy them on the cluster
# - a devops pipeline to deploy the chart / manifest.
# - import the chart to the local registry, if there is no internet access, the container images also need to be imported
# - a secret with a user to use as imagePullSecret for the deployment to be able 
# to pull images from the local registry

locals {
  helm_values = merge(var.helm_values, {})
  repos = [
    {
      "src_registry"  = "quay.io",
      "repo"          = "jetstack/cert-manager-controller",
      "dest_registry" = "${var.region}.ocir.io"
      "dest_ns"       = "${var.object_storage_namespace}"
      "dest_repo"     = "${var.oss_images_repo_prefix}/cert-manager/cert-manager-controller"
      "version"       = "${var.cert_manager_version}"
    },
    {
      "src_registry"  = "quay.io",
      "repo"          = "jetstack/cert-manager-webhook",
      "dest_registry" = "${var.region}.ocir.io"
      "dest_ns"       = "${var.object_storage_namespace}"
      "dest_repo"     = "${var.oss_images_repo_prefix}/cert-manager-webhook"
      "version"       = "${var.cert_manager_version}"
    },
    {
      "src_registry"  = "quay.io",
      "repo"          = "jetstack/cert-manager-cainjector",
      "dest_registry" = "${var.region}.ocir.io"
      "dest_ns"       = "${var.object_storage_namespace}"
      "dest_repo"     = "${var.oss_images_repo_prefix}/cert-manager-cainjector"
      "version"       = "${var.cert_manager_version}"
    },
    {
      "src_registry"  = "quay.io",
      "repo"          = "jetstack/cert-manager-acmesolver",
      "dest_registry" = "${var.region}.ocir.io"
      "dest_ns"       = "${var.object_storage_namespace}"
      "dest_repo"     = "${var.oss_images_repo_prefix}/cert-manager-acmesolver"
      "version"       = "${var.cert_manager_version}"
    },
    {
      "src_registry"  = "quay.io",
      "repo"          = "jetstack/cert-manager-ctl",
      "dest_registry" = "${var.region}.ocir.io"
      "dest_ns"       = "${var.object_storage_namespace}"
      "dest_repo"     = "${var.oss_images_repo_prefix}/cert-manager-ctl"
      "version"       = "${var.cert_manager_version}"
    }
  ]
  charts = [
    {
      "repo_name"     = "jetstack"
      "repo_url"      = "https://charts.jetstack.io"
      "chart_name"    = "cert-manager"
      "chart_version" = "${var.cert_manager_version}"
    }
  ]
}

module "push_cert_manager_chart" {
  for_each                 = { for c in local.charts : c["repo_name"] => c }
  source                   = "../../../../devops/ocir/push_helm_chart"
  region                   = var.region
  oci_profile              = var.oci_profile
  compartment_id           = var.devops_compartment_id
  object_storage_namespace = var.object_storage_namespace
  oss_charts_repo_prefix   = var.oss_charts_repo_prefix
  chart                    = each.value
}

module "push_cert_manager_images" {
  for_each                 = { for r in local.repos : r["repo"] => r if var.push_oss_images }
  source                   = "../../../../devops/ocir/push_image"
  region                   = var.region
  oci_profile              = var.oci_profile
  compartment_id           = var.devops_compartment_id
  object_storage_namespace = var.object_storage_namespace
  oss_images_repo_prefix   = var.oss_images_repo_prefix
  repo                     = each.value
}

module "cert_manager_chart_devops_artifact" {
  source        = "../../../../devops/artifacts/helm_chart"
  display_name  = "cert_manager"
  chart_url     = "oci://${var.region}.ocir.io/${var.object_storage_namespace}/${var.oss_charts_repo_prefix}/jetstack/cert-manager"
  chart_version = var.cert_manager_version
  project_id    = var.devops_project_id
  defined_tags  = var.defined_tags
}

resource "oci_devops_deploy_stage" "cert_manager" {
  are_hooks_enabled  = "false"
  deploy_pipeline_id = oci_devops_deploy_pipeline.cert_manager_add_on.id
  deploy_stage_predecessor_collection {
    items {
      id = oci_devops_deploy_pipeline.cert_manager_add_on.id
    }
  }
  deploy_stage_type                 = "OKE_HELM_CHART_DEPLOYMENT"
  description                       = "Deploy Cert Manager"
  display_name                      = "cert-manager"
  defined_tags                      = var.defined_tags
  helm_chart_deploy_artifact_id     = module.cert_manager_chart_devops_artifact.artifact.id
  is_debug_enabled                  = "false"
  is_force_enabled                  = "false"
  max_history                       = "0"
  namespace                         = "kube-system"
  oke_cluster_deploy_environment_id = var.devops_environment_id
  release_name                      = "cert-manager"
  rollback_policy {
    policy_type = "NO_STAGE_ROLLBACK_POLICY"
  }
  set_values {
    dynamic "items" {
      for_each = local.helm_values
      content {
        name  = items.key
        value = items.value
      }
    }
  }
  should_cleanup_on_fail            = "false"
  should_not_wait                   = "false"
  should_reset_values               = "false"
  should_reuse_values               = "false"
  should_skip_crds                  = "false"
  should_skip_render_subchart_notes = "false"
  timeout_in_seconds                = "600"
  values_artifact_ids               = []
  lifecycle {
    ignore_changes = [defined_tags]
  }
}
