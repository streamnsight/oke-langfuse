locals {
  repos = [
    {
      "src_registry"  = "registry.k8s.io",
      "repo"          = "metrics-server/metrics-server",
      "dest_registry" = "${var.region}.ocir.io"
      "dest_ns"       = "${var.object_storage_namespace}"
      "dest_repo"     = "${var.oss_images_repo_prefix}/metrics-server"
      "version"       = "${var.metrics_server_image_version}"
    }
  ]
  charts = [
    {
      "repo_name"     = "metrics-server"
      "repo_url"      = "https://kubernetes-sigs.github.io/metrics-server/"
      "chart_name"    = "metrics-server"
      "chart_version" = "${var.metrics_server_chart_version}"
    }
  ]
  helm_values = merge(var.helm_values, {
    "image.repository" = "${var.region}.ocir.io/${var.object_storage_namespace}/${var.oss_images_repo_prefix}/metrics-server"
    "image.tag"        = var.metrics_server_image_version
  })
}

module "push_metrics_server_chart" {
  for_each                 = { for c in local.charts : c["repo_name"] => c }
  source                   = "../../../../devops/ocir/push_helm_chart"
  region                   = var.region
  oci_profile              = var.oci_profile
  compartment_id           = var.devops_compartment_id
  object_storage_namespace = var.object_storage_namespace
  oss_charts_repo_prefix   = var.oss_charts_repo_prefix
  chart                    = each.value
}

module "push_metrics_server_images" {
  for_each                 = { for r in local.repos : r["repo"] => r }
  source                   = "../../../../devops/ocir/push_image"
  region                   = var.region
  oci_profile              = var.oci_profile
  compartment_id           = var.devops_compartment_id
  object_storage_namespace = var.object_storage_namespace
  oss_images_repo_prefix   = var.oss_images_repo_prefix
  repo                     = each.value
}

module "metrics_server_chart_devops_artifact" {
  source        = "../../../../devops/artifacts/helm_chart"
  display_name  = "metrics-server"
  chart_url     = "oci://${var.region}.ocir.io/${var.object_storage_namespace}/${var.oss_charts_repo_prefix}/metrics-server/metrics-server"
  chart_version = var.metrics_server_chart_version
  project_id    = var.devops_project_id
  defined_tags  = var.defined_tags
}

resource "oci_devops_deploy_stage" "metrics-server" {
  are_hooks_enabled  = "false"
  deploy_pipeline_id = oci_devops_deploy_pipeline.metrics_server_add_on.id
  deploy_stage_predecessor_collection {
    items {
      id = oci_devops_deploy_pipeline.metrics_server_add_on.id
    }
  }
  deploy_stage_type                 = "OKE_HELM_CHART_DEPLOYMENT"
  description                       = "Deploy Metrics Server"
  display_name                      = "metrics-server"
  defined_tags                      = var.defined_tags
  helm_chart_deploy_artifact_id     = module.metrics_server_chart_devops_artifact.artifact.id
  is_debug_enabled                  = "false"
  is_force_enabled                  = "false"
  max_history                       = "0"
  namespace                         = "kube-system"
  oke_cluster_deploy_environment_id = var.devops_environment_id
  release_name                      = "metrics-server"
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
  #test_load_balancer_config = <<Optional value not found in discovery>>
  timeout_in_seconds = "600"
  #traffic_shift_target = <<Optional value not found in discovery>>
  values_artifact_ids = []
  #wait_criteria = <<Optional value not found in discovery>>
  lifecycle {
    ignore_changes = [defined_tags]
  }
}


resource "oci_devops_deploy_pipeline" "metrics_server_add_on" {
  # deploy_pipeline_parameters {
  # }
  description  = "Metrics Server Add-on"
  display_name = "metrics_server_add_on"
  project_id   = var.devops_project_id
  defined_tags = var.defined_tags
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_devops_deployment" "metrics_server_deployment" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.metrics_server_add_on.id
  deployment_type    = "PIPELINE_DEPLOYMENT"
  display_name       = "metrics_server_add_on"
  defined_tags       = var.defined_tags
  #previous_deployment_id = <<Optional value not found in discovery>>
  trigger_new_devops_deployment = tostring(var.force_deployment)
  depends_on = [
    oci_devops_deploy_stage.metrics-server,
    module.push_metrics_server_chart,
    module.push_metrics_server_images,
    module.metrics_server_chart_devops_artifact
  ]
  lifecycle {
    ignore_changes = [defined_tags]
  }
}
