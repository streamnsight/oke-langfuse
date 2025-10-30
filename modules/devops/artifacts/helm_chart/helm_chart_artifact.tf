# Artifacts: DevOps project artifacts
resource "oci_devops_deploy_artifact" "helm_chart" {
  argument_substitution_mode = var.argument_substitution_mode
  deploy_artifact_source {
    chart_url                   = var.chart_url
    deploy_artifact_source_type = "HELM_CHART"
    deploy_artifact_version     = var.chart_version
    helm_verification_key_source {
      #current_public_key = <<Optional value not found in discovery>>
      #previous_public_key = <<Optional value not found in discovery>>
      #vault_secret_id = <<Optional value not found in discovery>>
      verification_key_source_type = "NONE"
    }
    #image_digest = <<Optional value not found in discovery>>
    #image_uri = <<Optional value not found in discovery>>
    #repository_id = <<Optional value not found in discovery>>
  }
  deploy_artifact_type = "HELM_CHART"
  description          = var.display_name
  display_name         = var.display_name
  defined_tags         = var.defined_tags
  project_id           = var.project_id
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

output "artifact" {
  value = oci_devops_deploy_artifact.helm_chart
}