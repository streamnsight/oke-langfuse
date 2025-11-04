resource "oci_devops_deploy_pipeline" "oci_genai_gateway" {
  # deploy_pipeline_parameters {
  # }
  description  = "OCI GenAI Gateway"
  display_name = "oci_genai_gateway"
  project_id   = var.devops_project_id
  defined_tags = var.defined_tags
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_devops_deploy_artifact" "oci_genai_gateway_manifest" {
  argument_substitution_mode = "SUBSTITUTE_PLACEHOLDERS"
  deploy_artifact_source {
    base64encoded_content       = local.manifest_yaml
    deploy_artifact_source_type = "INLINE"
  }
  deploy_artifact_type = "KUBERNETES_MANIFEST"
  description          = "OCI GenAI Gateway manifest"
  display_name         = "oci-genai-gateway-manifest"
  defined_tags         = var.defined_tags
  project_id           = var.devops_project_id
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_devops_deploy_stage" "oci_genai_gateway" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.oci_genai_gateway.id
  deploy_stage_predecessor_collection {
    items {
      id = oci_devops_deploy_pipeline.oci_genai_gateway.id
    }
  }
  deploy_stage_type = "OKE_DEPLOYMENT"
  description       = "Deploy OCI GenAI Gateway"
  display_name      = "oci_genai_gateway"
  defined_tags      = var.defined_tags
  kubernetes_manifest_deploy_artifact_ids = [
    oci_devops_deploy_artifact.oci_genai_gateway_manifest.id,
  ]
  namespace                         = "langfuse"
  oke_cluster_deploy_environment_id = var.devops_environment_id
  rollback_policy {
    policy_type = "AUTOMATED_STAGE_ROLLBACK_POLICY"
  }
  lifecycle {
    ignore_changes = [defined_tags]
  }
}


resource "oci_devops_deployment" "oci_genai_gateway_deployment" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.oci_genai_gateway.id
  deployment_type    = "PIPELINE_DEPLOYMENT"
  display_name       = "oci_genai_gateway"
  defined_tags       = var.defined_tags
  #previous_deployment_id = <<Optional value not found in discovery>>
  trigger_new_devops_deployment = var.force_deployment
  depends_on = [
    # module.push_cert_manager_images,
    oci_devops_deploy_artifact.oci_genai_gateway_manifest,
    oci_devops_deploy_stage.oci_genai_gateway
  ]
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

