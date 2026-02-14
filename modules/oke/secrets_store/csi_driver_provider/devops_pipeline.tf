## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

locals {
  namespace = data.oci_objectstorage_namespace.ns.namespace
  charts = [
    {
      "repo_name"     = "oci-secrets-store-provider"
      "repo_url"      = "https://oracle.github.io/oci-secrets-store-csi-driver-provider/charts"
      "chart_name"    = "oci-secrets-store-csi-driver-provider"
      "chart_version" = "${var.secrets_store_csi_provider_helm_chart_version}"
    }
  ]
}

module "push_secrets_store_csi_provider_chart" {
  for_each                 = { for c in local.charts : c["repo_name"] => c }
  source                   = "../../../devops/ocir/push_helm_chart"
  region                   = var.region
  oci_profile              = var.oci_profile
  compartment_id           = var.compartment_id
  object_storage_namespace = local.namespace
  oss_charts_repo_prefix   = var.deploy_id
  chart                    = each.value
}

resource "oci_artifacts_repository" "helm_chart_values_repository" {
  compartment_id  = var.compartment_id
  display_name    = "secrets_store_csi_provider_helm_chart_values_repo"
  is_immutable    = false # Set to true if artifacts in this repository should be immutable
  repository_type = "GENERIC"
}

resource "oci_generic_artifacts_content_artifact_by_path" "helm_chart_values_artifact" {
  #Required
  artifact_path = "values.yaml"
  repository_id = oci_artifacts_repository.helm_chart_values_repository.id
  version       = "0.1.0"
  content       = file("${path.module}/values.template.yaml")

  # delete the resource from artifact repo on destroy as it blocks destroy of the artifact repo itself
  provisioner "local-exec" {
    when    = destroy
    command = <<-CMD
      oci artifacts generic artifact delete --artifact-id ${self.id} --force
    CMD
  }

}

resource "oci_devops_deploy_artifact" "helm_chart_values_deploy_artifact" {
  #Required
  argument_substitution_mode = "SUBSTITUTE_PLACEHOLDERS"
  deploy_artifact_source {
    #Required
    deploy_artifact_source_type = "GENERIC_ARTIFACT"

    #Optional
    deploy_artifact_path    = "values.yaml"
    deploy_artifact_version = "0.1.0"
    repository_id           = oci_artifacts_repository.helm_chart_values_repository.id
  }
  deploy_artifact_type = "GENERIC_FILE"
  project_id           = var.devops_project_id

  #Optional
  defined_tags = var.defined_tags
  description  = "secrets_store_csi_provider helm chart values"
  display_name = "secrets_store_csi_provider_helm_chart_values"
  depends_on   = [oci_generic_artifacts_content_artifact_by_path.helm_chart_values_artifact]

  lifecycle {
    ignore_changes = [
      defined_tags
    ]
  }
}


module "secrets_store_csi_provider_chart_devops_artifact" {
  source        = "../../../devops/artifacts/helm_chart"
  display_name  = "secrets_store_csi_provider"
  chart_url     = "oci://${var.region}.ocir.io/${local.namespace}/${var.deploy_id}/oci-secrets-store-provider/oci-secrets-store-csi-driver-provider"
  chart_version = var.secrets_store_csi_provider_helm_chart_version
  project_id    = var.devops_project_id
  defined_tags  = var.defined_tags
}


resource "oci_devops_deploy_pipeline" "secrets_store_csi_provider" {
  # deploy_pipeline_parameters {
  # }
  description  = "secrets_store_csi_provider"
  display_name = "secrets_store_csi_provider"
  project_id   = var.devops_project_id
  defined_tags = var.defined_tags

  deploy_pipeline_parameters {
    dynamic "items" {
      for_each = [for i in [
        {
          name          = "REGION"
          description   = "region"
          default_value = var.region
        }
      ] : i if coalesce(i.default_value, "x") != "x"]
      content {
        default_value = items.value.default_value
        description   = items.value.description
        name          = items.value.name
      }
    }
  }

  lifecycle {
    ignore_changes = [defined_tags]
    replace_triggered_by = [
    ]
  }
}


resource "oci_devops_deploy_stage" "secrets_store_csi_provider" {
  are_hooks_enabled  = "false"
  deploy_pipeline_id = oci_devops_deploy_pipeline.secrets_store_csi_provider.id
  deploy_stage_predecessor_collection {
    items {
      id = oci_devops_deploy_pipeline.secrets_store_csi_provider.id
    }
  }
  deploy_stage_type                 = "OKE_HELM_CHART_DEPLOYMENT"
  description                       = "Deploy secrets_store_csi_provider Helm Chart"
  display_name                      = "secrets-store-csi-provider-helm-chart"
  defined_tags                      = var.defined_tags
  helm_chart_deploy_artifact_id     = module.secrets_store_csi_provider_chart_devops_artifact.artifact.id
  is_debug_enabled                  = "false"
  is_force_enabled                  = "false"
  is_uninstall_on_stage_delete      = "true"
  max_history                       = "0"
  namespace                         = "kube-system"
  oke_cluster_deploy_environment_id = var.devops_environment_id
  release_name                      = "secrets-store-csi-provider"
  rollback_policy {
    policy_type = "NO_STAGE_ROLLBACK_POLICY"
  }
  should_cleanup_on_fail            = "false"
  should_not_wait                   = "false"
  should_reset_values               = "false"
  should_reuse_values               = "false"
  should_skip_crds                  = "false"
  should_skip_render_subchart_notes = "false"
  #test_load_balancer_config = <<Optional value not found in discovery>>
  timeout_in_seconds = "900"
  #traffic_shift_target = <<Optional value not found in discovery>>
  values_artifact_ids = [oci_devops_deploy_artifact.helm_chart_values_deploy_artifact.id]
  #wait_criteria = <<Optional value not found in discovery>>
  lifecycle {
    ignore_changes = [defined_tags]
  }
}


resource "oci_devops_deployment" "secrets_store_csi_provider_deployment" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.secrets_store_csi_provider.id
  deployment_type    = "PIPELINE_DEPLOYMENT"
  display_name       = "secrets_store_csi_provider"
  defined_tags       = var.defined_tags
  #previous_deployment_id = <<Optional value not found in discovery>>
  trigger_new_devops_deployment = tostring(var.force_deployment)

  depends_on = [
    oci_devops_deploy_stage.secrets_store_csi_provider,
    module.push_secrets_store_csi_provider_chart,
    module.secrets_store_csi_provider_chart_devops_artifact
  ]
  lifecycle {
    ignore_changes = [defined_tags]
  }
}
