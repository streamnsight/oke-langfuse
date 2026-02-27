## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_artifacts_repository" "nginx_ingress_controller_manifest_repository" {
  compartment_id  = var.compartment_id
  display_name    = "nginx_ingress_controller_manifest_repo"
  is_immutable    = false # Set to true if artifacts in this repository should be immutable
  repository_type = "GENERIC"

  # Purge any remaining artifacts before destroying the repository.
  provisioner "local-exec" {
    when    = destroy
    on_failure = continue
    command = <<-CMD
      set -e
      REPO_ID="${self.id}"
      for i in $(seq 1 12); do
        IDS=$(oci artifacts generic artifact list --repository-id "$REPO_ID" --all --query 'data.items[].id' --raw-output | tr -d '\r')
        if [ -z "$IDS" ]; then
          exit 0
        fi
        for id in $IDS; do
          oci artifacts generic artifact delete --artifact-id "$id" --force || true
        done
        sleep 5
      done
      oci artifacts generic artifact list --repository-id "$REPO_ID" --all --query 'data.items[].id'
      echo "Repository still has artifacts after retries." 1>&2
      exit 1
    CMD
  }
}

resource "oci_generic_artifacts_content_artifact_by_path" "nginx_ingress_controller_manifest_artifact" {
  #Required
  artifact_path = "nginx-ingress-controller.yaml"
  repository_id = oci_artifacts_repository.nginx_ingress_controller_manifest_repository.id
  version       = "0.1.0"
  content       = file("${path.module}/manifests/nginx-ingress-controller.yaml")

  # delete the resource from artifact repo on destroy as it blocks destroy of the artifact repo itself
  provisioner "local-exec" {
    when    = destroy
    on_failure = continue
    command = <<-CMD
      oci artifacts generic artifact delete --artifact-id ${self.id} --force
    CMD
  }

}
resource "oci_devops_deploy_artifact" "nginx_ingress_controller_manifest" {
  argument_substitution_mode = "SUBSTITUTE_PLACEHOLDERS"
  deploy_artifact_source {
    #Required
    deploy_artifact_source_type = "GENERIC_ARTIFACT"

    #Optional
    deploy_artifact_path    = "nginx-ingress-controller.yaml"
    deploy_artifact_version = "0.1.0"
    repository_id           = oci_artifacts_repository.nginx_ingress_controller_manifest_repository.id
  }
  deploy_artifact_type = "KUBERNETES_MANIFEST"
  description          = "nginx Ingress Controller manifest"
  display_name         = "nginx-ingress-controller-manifest"
  defined_tags         = var.defined_tags
  project_id           = var.devops_project_id
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_devops_deploy_pipeline" "nginx_ingress_controller" {
  # deploy_pipeline_parameters {
  # }
  description  = "nginx Ingress Controller"
  display_name = "nginx-ingress-controller"
  project_id   = var.devops_project_id
  defined_tags = var.defined_tags
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_devops_deploy_stage" "nginx_ingress_controller" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.nginx_ingress_controller.id
  deploy_stage_predecessor_collection {
    items {
      id = oci_devops_deploy_pipeline.nginx_ingress_controller.id
    }
  }
  deploy_stage_type = "OKE_DEPLOYMENT"
  description       = "Deploy nginx Ingress Controller"
  display_name      = "nginx-ingress-controller"
  defined_tags      = var.defined_tags
  kubernetes_manifest_deploy_artifact_ids = [
    oci_devops_deploy_artifact.nginx_ingress_controller_manifest.id,
  ]
  oke_cluster_deploy_environment_id = var.devops_environment_id
  rollback_policy {
    policy_type = "AUTOMATED_STAGE_ROLLBACK_POLICY"
  }
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_devops_deployment" "nginx_ingress_controller_deployment" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.nginx_ingress_controller.id
  deployment_type    = "PIPELINE_DEPLOYMENT"
  display_name       = "nginx-ingress-controller"
  defined_tags       = var.defined_tags
  #previous_deployment_id = <<Optional value not found in discovery>>
  trigger_new_devops_deployment = tostring(var.force_deployment)
  depends_on = [
    oci_devops_deploy_stage.nginx_ingress_controller,
    oci_devops_deploy_artifact.nginx_ingress_controller_manifest,
  ]
  lifecycle {
    ignore_changes = [defined_tags]
  }
}


data "oci_load_balancer_load_balancers" "load_balancers" {
  #Required
  compartment_id = var.compartment_id

  #Optional
  detail = "full"
  # display_name = "langfuse-web-${local.deploy_id}"

  depends_on = [oci_devops_deployment.nginx_ingress_controller_deployment]
}
