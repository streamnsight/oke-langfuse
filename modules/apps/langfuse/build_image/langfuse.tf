## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_generic_artifacts_content_artifact_by_path" "langfuse_image_build_script_artifact" {
  #Required
  artifact_path = "build_langfuse_image.sh"
  repository_id = var.artifact_repo_id
  version       = "0.1.0"
  content       = file("${path.module}/scripts/build_langfuse_image.sh")

  # delete the resource from artifact repo on destroy as it blocks destroy of the artifact repo itself
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      oci artifacts generic artifact delete --artifact-id ${self.id} --force
    CMD
  }
}

module "build_langfuse_image_shell_stage" {
  source                = "../../../devops/deployment_stages/shell_stage"
  compartment_id        = var.compartment_id
  subnet_id             = var.subnet_id
  stage_name            = "build_langfuse_image"
  devops_project_id     = var.devops_project_id
  devops_environment_id = var.devops_environment_id
  deploy_pipeline_parameters = [
    {
      name          = "SSH_PRIVATE_KEY_SECRET_OCID"
      default_value = var.builder_instance_private_key_secret_ocid
      description   = "Private key for access to builder instance"
    },
    {
      name          = "BUILDER_INSTANCE_IP"
      default_value = var.builder_instance_private_ip
      description   = "setupo script"
    },
    {
      name          = "LANGFUSE_IMAGE_BUILD_SCRIPT_ARTIFACT_OCID"
      default_value = oci_generic_artifacts_content_artifact_by_path.langfuse_image_build_script_artifact.id
      description   = "OCID of the artifact"
    },
    {
      name          = "REGISTRY_OCID"
      default_value = var.artifact_repo_id
      description   = "OCID of the artifact repository"
    }
  ]
  command_spec_content = file("${path.module}/scripts/command_spec.yaml")
  timeout              = 3600
}

