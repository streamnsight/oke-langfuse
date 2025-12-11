locals {
  namespace = data.oci_objectstorage_namespace.ns.namespace
  charts = [
    {
      "repo_name"     = "langfuse"
      "repo_url"      = "https://langfuse.github.io/langfuse-k8s"
      "chart_name"    = "langfuse"
      "chart_version" = "${var.langfuse_helm_chart_version}"
    }
  ]
}

# set the langfuse container image version into a file, triggered by a change in the chart version that contains that info
# but is not accessible via terraform directly
resource "terraform_data" "langfuse_version" {
  input = var.langfuse_helm_chart_version
  triggers_replace = {
    helm_chart_version = var.langfuse_helm_chart_version
  }
  provisioner "local-exec" {
    command = <<EOT
    helm repo add langfuse https://langfuse.github.io/langfuse-k8s
    helm repo update
    export LANGFUSE_VERSION=$(helm show chart langfuse/langfuse --version ${var.langfuse_helm_chart_version} | grep appVersion | awk '{print $2}')
    echo $LANGFUSE_VERSION > ${path.module}/langfuse.version
    EOT
  }
}
#echo $(git ls-remote --tags https://github.com/langfuse/langfuse | sort -t/ -k3V | tail -1 | awk -F '/' '{print $3}') > ${path.module}/langfuse.version"

module "push_langfuse_chart" {
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
  display_name    = "langfuse_helm_chart_values_repo"
  is_immutable    = false # Set to true if artifacts in this repository should be immutable
  repository_type = "GENERIC"
}

resource "oci_generic_artifacts_content_artifact_by_path" "helm_chart_values_artifact" {
  #Required
  artifact_path = "values.yaml"
  repository_id = oci_artifacts_repository.helm_chart_values_repository.id
  version       = "0.1.0"
  source        = "${path.module}/scripts/values.template.yaml"

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
  description  = "langfuse helm chart values"
  display_name = "langfuse_helm_chart_values"
  depends_on   = [oci_generic_artifacts_content_artifact_by_path.helm_chart_values_artifact]

  lifecycle {
    ignore_changes = [
      defined_tags
    ]
  }
}


module "langfuse_chart_devops_artifact" {
  source        = "../../../devops/artifacts/helm_chart"
  display_name  = "langfuse"
  chart_url     = "oci://${var.region}.ocir.io/${local.namespace}/${var.deploy_id}/langfuse/langfuse"
  chart_version = var.langfuse_helm_chart_version
  project_id    = var.devops_project_id
  defined_tags  = var.defined_tags
}


resource "oci_devops_deploy_pipeline" "langfuse" {
  # deploy_pipeline_parameters {
  # }
  description  = "Langfuse"
  display_name = "langfuse"
  project_id   = var.devops_project_id
  defined_tags = var.defined_tags

  deploy_pipeline_parameters {
    dynamic "items" {
      for_each = [for i in [
        {
          name          = "REGION"
          description   = "region"
          default_value = var.region
        },
        {
          name          = "TENANCY_NAMESPACE"
          description   = "Tenancy namespace"
          default_value = local.namespace
        },
        {
          name          = "DEPLOY_ID"
          description   = "Deployment ID"
          default_value = var.deploy_id
        },
        {
          name          = "LANGFUSE_IMAGE_TAG"
          description   = "Langfuse container image tag / version"
          default_value = chomp(file("${path.module}/langfuse.version"))
        },
        {
          name          = "LANGFUSE_HOSTNAME"
          description   = "Langfuse hostname"
          default_value = var.langfuse_hostname
        },
        {
          name          = "REDIS_HOSTNAME"
          description   = "Redis hostname"
          default_value = var.redis_hostname
        },
        {
          name          = "LANGFUSE_OBJECT_STORAGE_BUCKET"
          description   = "Langfuse trace storage bucket"
          default_value = var.object_storage_bucket
        }
      ] : i if coalesce(i.default_value, "x") != "x"]
      content {
        default_value = items.value.default_value
        description   = items.value.description
        name          = items.value.name
      }
    }
  }

  #   depends_on = [
  #     null_resource.langfuse_version
  #   ]
  lifecycle {
    ignore_changes = [defined_tags]
    replace_triggered_by = [
      terraform_data.langfuse_version,
      oci_generic_artifacts_content_artifact_by_path.helm_chart_values_artifact
    ]
  }
}


resource "oci_devops_deploy_stage" "langfuse" {
  are_hooks_enabled  = "false"
  deploy_pipeline_id = oci_devops_deploy_pipeline.langfuse.id
  deploy_stage_predecessor_collection {
    items {
      id = oci_devops_deploy_pipeline.langfuse.id
    }
  }
  deploy_stage_type                 = "OKE_HELM_CHART_DEPLOYMENT"
  description                       = "Deploy Langfuse Helm Chart"
  display_name                      = "langfuse-helm-chart"
  defined_tags                      = var.defined_tags
  helm_chart_deploy_artifact_id     = module.langfuse_chart_devops_artifact.artifact.id
  is_debug_enabled                  = "false"
  is_force_enabled                  = "false"
  max_history                       = "0"
  namespace                         = "langfuse"
  oke_cluster_deploy_environment_id = var.devops_environment_id
  release_name                      = "langfuse"
  rollback_policy {
    policy_type = "NO_STAGE_ROLLBACK_POLICY"
  }
  #   set_values {
  #     dynamic "items" {
  #       for_each = {} 
  #     #   yamldecode(templatefile("${path.module}/scripts/values.template.yaml", {
  #     #     REGION                         = var.region
  #     #     TENANCY_NAMESPACE              = local.namespace
  #     #     LANGFUSE_IMAGE_TAG             = file("${path.module}/langfuse.version")
  #     #     LANGFUSE_HOSTNAME              = "TO_BE_UPDATED"
  #     #     REDIS_HOSTNAME                 = var.redis_hostname
  #     #     LANGFUSE_OBJECT_STORAGE_BUCKET = local.object_storage_bucket

  #     #   }))
  #       content {
  #         name  = items.key
  #         value = items.value
  #       }
  #     }
  #   }
  should_cleanup_on_fail            = "false"
  should_not_wait                   = "false"
  should_reset_values               = "false"
  should_reuse_values               = "false"
  should_skip_crds                  = "false"
  should_skip_render_subchart_notes = "false"
  #test_load_balancer_config = <<Optional value not found in discovery>>
  timeout_in_seconds = "600"
  #traffic_shift_target = <<Optional value not found in discovery>>
  values_artifact_ids = [oci_devops_deploy_artifact.helm_chart_values_deploy_artifact.id]
  #wait_criteria = <<Optional value not found in discovery>>
  lifecycle {
    ignore_changes = [defined_tags]
  }
  #   depends_on = [
  #     null_resource.langfuse_version
  #   ]
}


resource "oci_devops_deployment" "langfuse_deployment" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.langfuse.id
  deployment_type    = "PIPELINE_DEPLOYMENT"
  display_name       = "langfuse"
  defined_tags       = var.defined_tags
  #previous_deployment_id = <<Optional value not found in discovery>>
  trigger_new_devops_deployment = tostring(var.force_deployment)

  depends_on = [
    oci_devops_deploy_stage.langfuse,
    module.push_langfuse_chart,
    module.langfuse_chart_devops_artifact,
    null_resource.build_image
  ]
  lifecycle {
    ignore_changes = [defined_tags]
  }
}
