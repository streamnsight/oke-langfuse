## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_artifacts_repository" "artifact_repository" {
  compartment_id  = var.devops_compartment_id
  display_name    = "artifact_repo_for_${local.deploy_id}"
  is_immutable    = false # Set to true if artifacts in this repository should be immutable
  repository_type = "GENERIC"

  # Purge any remaining artifacts before destroying the repository.
  provisioner "local-exec" {
    when    = destroy
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

locals {
  artifact_repo_id = oci_artifacts_repository.artifact_repository.id
}

resource "oci_generic_artifacts_content_artifact_by_path" "builder_setup_artifact" {
  #Required
  artifact_path = "install_dependencies.sh"
  repository_id = local.artifact_repo_id
  version       = "0.1.0"
  content       = file("${path.module}/scripts/install_dependencies.sh")

  # delete the resource from artifact repo on destroy as it blocks destroy of the artifact repo itself
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-CMD
      oci artifacts generic artifact delete --artifact-id ${self.id} --force
    CMD
  }
}

module "builder_instance" {
  source              = "./modules/compute/builder_instance"
  compartment_id      = local.effective_cluster_compartment_id
  availability_domain = local.ADs[0]
  subnet_id           = local.workload_subnet_id
  display_name        = "${local.cluster_name_sanitized}-builder"
  compute_shape       = local.effective_builder_shape
  image_id            = local.effective_builder_image_id
  metadata = {
    deploy_id                          = local.deploy_id
    cluster_id                         = local.target_cluster_id
    langfuse_helm_chart_version        = var.langfuse_helm_chart_version
    lb_subnet_id                       = var.use_existing_cluster ? data.oci_containerengine_cluster.target.endpoint_config[0].subnet_id : (var.use_existing_vcn ? var.public_lb_subnet : oci_core_subnet.oke_lb_subnet[0].id)
    oci_profile                        = var.oci_profile
    cluster_compartment_id             = local.effective_cluster_compartment_id
    secrets_store_vault_compartment_id = var.secrets_store_vault_compartment_id
    secrets_store_vault_id             = var.secrets_store_vault_id
    secrets_store_key_id               = var.secrets_store_key_id
  }
  ssh_authorized_keys = var.ssh_public_key != null ? "${var.ssh_public_key}\n${data.external.builder_ssh_key_to_vault.result.public_key}" : "${data.external.builder_ssh_key_to_vault.result.public_key}"
  policies = [
    "manage repos",           # to push images
    "manage instance-family", # to shut down when done
    "manage cluster-family"   # to access the cluster
  ]

  providers = {
    oci             = oci
    oci.home_region = oci.home_region
  }
}

# generate a public / private key pair and store the private key in vault
# use data external to avoid exposing this key in terraform state
data "external" "builder_ssh_key_to_vault" {
  program = ["./scripts/builder_ssh_key.sh"]
  query = {
    oci_profile                        = var.oci_profile
    secrets_store_vault_compartment_id = var.secrets_store_vault_compartment_id
    secrets_store_vault_id             = var.secrets_store_vault_id
    secrets_store_key_id               = var.secrets_store_key_id
    secret_name                        = "${local.deploy_id}_LANGFUSE_BUILDER_PRIVATE_KEY"
  }
}


module "builder_setup_shell_stage" {
  source                = "./modules/devops/deployment_stages/shell_stage"
  compartment_id        = var.devops_compartment_id
  subnet_id             = local.workload_subnet_id # shell stage needs to reach to the cluster endpoint
  stage_name            = "builder_setup"
  shape_name            = local.ci_shape_selected
  devops_project_id     = module.devops_setup.project_id
  devops_environment_id = module.devops_target_cluster_env.environment_id
  deploy_pipeline_parameters = [
    {
      name          = "SSH_PRIVATE_KEY_SECRET_OCID"
      default_value = data.external.builder_ssh_key_to_vault.result.private_key_secret_ocid
      description   = "Private key for access to builder instance"
    },
    {
      name          = "BUILDER_INSTANCE_IP"
      default_value = module.builder_instance.details.private_ip
      description   = "setup script"
    },
    {
      name          = "BUILDER_INSTALL_DEPENDENCIES_ARTIFACT_OCID"
      default_value = oci_generic_artifacts_content_artifact_by_path.builder_setup_artifact.id
      description   = "OCID of the artifact"
    },
    {
      name          = "REGISTRY_OCID"
      default_value = local.artifact_repo_id
      description   = "OCID of the artifact repository"
    }
  ]
  command_spec_content = file("./scripts/command_spec.setup.yaml")
  depends_on           = [module.builder_instance]
}

module "builder_terminate_shell_stage" {
  source                = "./modules/devops/deployment_stages/shell_stage"
  compartment_id        = var.devops_compartment_id
  subnet_id             = local.workload_subnet_id
  stage_name            = "builder_terminate"
  shape_name            = local.ci_shape_selected
  devops_project_id     = module.devops_setup.project_id
  devops_environment_id = module.devops_target_cluster_env.environment_id
  deploy_pipeline_parameters = [
    {
      name          = "SSH_PRIVATE_KEY_SECRET_OCID"
      default_value = data.external.builder_ssh_key_to_vault.result.private_key_secret_ocid
      description   = "Private key for access to builder instance"
    },
    {
      name          = "BUILDER_INSTANCE_IP"
      default_value = module.builder_instance.details.private_ip
      description   = "setup script"
    },
    {
      name          = "REGISTRY_OCID"
      default_value = local.artifact_repo_id
      description   = "OCID of the artifact repository"
    }
  ]
  command_spec_content = file("./scripts/command_spec.terminate.yaml")
  depends_on = [
    module.builder_instance,
    module.builder_setup_shell_stage,
    module.oci_genai_gateway,
    module.build_langfuse_image,
    module.langfuse_chart
  ]
}


# resource "null_resource" "terminate_builder_instance" {
#   triggers = {
#     instance_id = module.builder_instance.details.instance_id
#   }
#   connection {
#     type        = "ssh"
#     user        = "opc"
#     private_key = module.builder_instance.details.private_key
#     host        = module.builder_instance.details.ip_address
#   }

#   provisioner "remote-exec" {
#     inline = [<<EOT
#       # terminate the builder instance
#       sleep 120
#       export INSTANCE_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".id")
#       oci compute instance terminate --auth instance_principal --instance-id $INSTANCE_OCID --force
#       EOT
#     ]
#   }

#   depends_on = [
#     module.oci_genai_gateway,
#     module.langfuse_chart,
#     # module.langfuse_ingress_tls,
#   ]
# }
