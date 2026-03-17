## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_devops_deploy_artifact" "commandspec" {
  argument_substitution_mode = "SUBSTITUTE_PLACEHOLDERS"
  deploy_artifact_source {
    # Inline Command Spec YAML
    base64encoded_content       = base64encode(var.command_spec_content)
    deploy_artifact_source_type = "INLINE"
  }
  deploy_artifact_type = "DEPLOYMENT_SPEC"
  description          = "${var.stage_name} shell stage command spec"
  display_name         = "${replace(var.stage_name, "_", "-")}-commandspec"
  defined_tags         = var.defined_tags
  project_id           = var.devops_project_id
  lifecycle {
    ignore_changes = [defined_tags]
  }

  # delete the resource from artifact repo on destroy as it blocks destroy of the artifact repo itself
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      oci artifacts generic artifact delete --artifact-id ${self.id} --force
    CMD
  }
}

resource "oci_devops_deploy_pipeline" "pipeline" {
  description  = var.stage_name
  display_name = replace(var.stage_name, "_", "-")
  deploy_pipeline_parameters {
    dynamic "items" {
      for_each = var.deploy_pipeline_parameters
      content {
        name          = items.value.name
        default_value = items.value.default_value
        description   = items.value.description
      }
    }
  }
  project_id   = var.devops_project_id
  defined_tags = var.defined_tags
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_devops_deploy_stage" "deploy_stage" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.pipeline.id
  deploy_stage_predecessor_collection {
    items { id = oci_devops_deploy_pipeline.pipeline.id }
  }
  deploy_stage_type                 = "SHELL"
  description                       = "Deploy ${var.stage_name} (Shell stage)"
  display_name                      = "${replace(var.stage_name, "_", "-")}-shell"
  defined_tags                      = var.defined_tags
  command_spec_deploy_artifact_id   = oci_devops_deploy_artifact.commandspec.id
  oke_cluster_deploy_environment_id = var.devops_environment_id
  container_config {
    #Required
    container_config_type = "CONTAINER_INSTANCE_CONFIG"
    network_channel {
      #Required
      network_channel_type = "SERVICE_VNIC_CHANNEL"
      subnet_id            = var.subnet_id

      #Optional
      nsg_ids = []
    }
    shape_config {
      #Required
      ocpus = 2

      #Optional
      memory_in_gbs = 8
    }
    shape_name     = var.shape_name
    compartment_id = var.compartment_id
  }

  rollback_policy { policy_type = "NO_STAGE_ROLLBACK_POLICY" }
  lifecycle { ignore_changes = [defined_tags] }
  timeout_in_seconds = var.timeout
}

resource "oci_devops_deployment" "deployment" {
  deploy_pipeline_id = oci_devops_deploy_pipeline.pipeline.id
  deployment_type    = "PIPELINE_DEPLOYMENT"
  display_name       = replace(var.stage_name, "_", "-")
  defined_tags       = var.defined_tags
  deployment_arguments {
    dynamic "items" {
      for_each = var.deploy_pipeline_parameters
      content {
        name  = items.value.name
        value = items.value.default_value
      }
    }
  }
  trigger_new_devops_deployment = "false"
  depends_on = [
    oci_devops_deploy_stage.deploy_stage,
    oci_devops_deploy_artifact.commandspec
  ]
  lifecycle { ignore_changes = [defined_tags] }
}
