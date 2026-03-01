## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

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


data "external" "create_oci_genai_gateway_vault_secrets" {
  program = ["${path.module}/scripts/create_vault_secrets.sh"]
  query = {
    deploy_id                          = var.deploy_id
    profile                            = var.oci_profile
    secrets_store_vault_compartment_id = var.secrets_store_vault_compartment_id
    secrets_store_vault_id             = var.secrets_store_vault_id
    secrets_store_key_id               = var.secrets_store_key_id
  }
}

resource "oci_generic_artifacts_content_artifact_by_path" "create_oci_genai_gateway_oke_secrets_script_artifact" {
  #Required
  artifact_path = "create_oci_genai_gateway_oke_secrets.sh"
  repository_id = var.artifact_repo_id
  version       = "0.1.0"
  content       = file("${path.module}/scripts/create_oci_genai_gateway_oke_secrets.sh")

  # delete the resource from artifact repo on destroy as it blocks destroy of the artifact repo itself
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      oci artifacts generic artifact delete --artifact-id ${self.id} --force
    CMD
  }
}

resource "oci_generic_artifacts_content_artifact_by_path" "oci_genai_gateway_image_build_script_artifact" {
  #Required
  artifact_path = "build_oci_genai_gateway_image.sh"
  repository_id = var.artifact_repo_id
  version       = "0.1.0"
  content       = file("${path.module}/scripts/build_oci_genai_gateway_image.sh")

  # delete the resource from artifact repo on destroy as it blocks destroy of the artifact repo itself
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      oci artifacts generic artifact delete --artifact-id ${self.id} --force
    CMD
  }
}

module "build_oci_genai_gateway_image_shell_stage" {
  source                = "../../devops/deployment_stages/shell_stage"
  compartment_id        = var.compartment_id
  subnet_id             = var.subnet_id
  stage_name            = "build_oci_genai_gateway_image"
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
      name          = "BUILD_OCI_GENAI_GATEWAY_IMAGE_ARTIFACT_OCID"
      default_value = oci_generic_artifacts_content_artifact_by_path.oci_genai_gateway_image_build_script_artifact.id
      description   = "OCID of the artifact"
    },
    {
      name          = "CREATE_OCI_GENAI_GATEWAY_SECRETS_SCRIPT_ARTIFACT_OCID"
      default_value = oci_generic_artifacts_content_artifact_by_path.create_oci_genai_gateway_oke_secrets_script_artifact.id
      description   = "OCID of the artifact"
    },
    {
      name          = "REGISTRY_OCID"
      default_value = var.artifact_repo_id
      description   = "OCID of the artifact repository"
    },
    {
      name          = "REGION"
      default_value = var.region
      description   = "cluster region"
    },
    {
      name          = "PROFILE"
      default_value = var.oci_profile
      description   = "OCI Profile"
    },
    {
      name          = "CLUSTER_ID"
      default_value = var.cluster_id
      description   = "Cluster ID"
    },
    {
      name          = "DEPLOY_ID"
      default_value = var.deploy_id
      description   = "DEPLOY ID"
    },
    {
      name          = "SECRET_STORE_VAULT_ID"
      default_value = var.secrets_store_vault_id
      description   = "OCID of the vault"
    },
    {
      name          = "SECRET_STORE_KEY_ID"
      default_value = var.secrets_store_key_id
      description   = "OCID of the key"
    },
    {
      name          = "COMPARTMENT_ID"
      default_value = var.secrets_store_vault_compartment_id
      description   = "Compartment ID"
    }
  ]
  command_spec_content = file("${path.module}/scripts/command_spec.yaml")
  depends_on           = [data.external.create_oci_genai_gateway_vault_secrets]
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
    module.build_oci_genai_gateway_image_shell_stage,
    oci_devops_deploy_stage.oci_genai_gateway
  ]
  lifecycle {
    ignore_changes = [defined_tags]
  }
}


resource "null_resource" "oci_genai_gateway_ocir_repo_cleanup" {
  triggers = {
    deploy_id         = var.deploy_id
    tenancy_namespace = var.tenancy_namespace
    compartment_id    = var.compartment_id
  }

  depends_on = [
    module.build_oci_genai_gateway_image_shell_stage
  ]

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      set -e
      REPO_NAME="${self.triggers.tenancy_namespace}/${self.triggers.deploy_id}/oci-genai-gateway"
      REPO_ID=$(oci artifacts container repository list \
        --compartment-id ${self.triggers.compartment_id} \
        --all \
        --query "data.items[?\"display-name\"=='${self.triggers.deploy_id}/oci-genai-gateway'].id | [0]" \
        --raw-output | tr -d '\r')
      if [ -n "$REPO_ID" ] && [ "$REPO_ID" != "null" ]; then
        oci artifacts container repository delete --repository-id "$REPO_ID" --force
      else
        echo "OCIR repo $REPO_NAME not found; skipping delete."
      fi
    CMD
  }
}
