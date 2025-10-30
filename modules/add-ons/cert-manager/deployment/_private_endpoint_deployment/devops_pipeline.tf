resource "oci_devops_deploy_pipeline" "cert_manager_add_on" {
  # deploy_pipeline_parameters {
  # }
  description  = "Cert Manager Add-on"
  display_name = "cert_manager_add_on"
  project_id   = var.devops_project_id
  defined_tags = var.defined_tags
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_devops_deployment" "cert_manager_deployment" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.cert_manager_add_on.id
  deployment_type    = "PIPELINE_DEPLOYMENT"
  display_name       = "cert_manager_add_on"
  defined_tags       = var.defined_tags
  #previous_deployment_id = <<Optional value not found in discovery>>
  trigger_new_devops_deployment = var.force_deployment
  depends_on = [
    module.push_cert_manager_chart,
    module.push_cert_manager_images,
    module.cert_manager_chart_devops_artifact,
    oci_devops_deploy_stage.cert_manager
  ]
  lifecycle {
    ignore_changes = [defined_tags]
  }
}
