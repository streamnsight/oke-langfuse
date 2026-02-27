## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_artifacts_repository" "artifact_repository" {
  compartment_id  = local.devops_compartment_id
  display_name    = "artifact_repo_for_${local.deploy_id}"
  is_immutable    = false # Set to true if artifacts in this repository should be immutable
  repository_type = "GENERIC"
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
  compartment_id      = var.cluster_compartment_id
  availability_domain = local.ADs[0]
  subnet_id           = var.use_existing_vcn ? local.node_pools[0]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id
  # subnet_id           = var.use_existing_vcn ? var.public_lb_subnet : oci_core_subnet.oke_lb_subnet[0].id
  display_name  = "${local.cluster_name_sanitized}-builder"
  compute_shape = local.node_pools[0].node_shape
  image_id      = local.node_pools[0].image_id
  metadata = {
    deploy_id                          = local.deploy_id
    cluster_id                         = oci_containerengine_cluster.oci_oke_cluster.id
    langfuse_helm_chart_version        = var.langfuse_helm_chart_version
    lb_subnet_id                       = var.use_existing_vcn ? var.public_lb_subnet : oci_core_subnet.oke_lb_subnet[0].id
    oci_profile                        = var.oci_profile
    secrets_store_vault_compartment_id = var.secrets_store_vault_compartment_id
    secrets_store_vault_id             = var.secrets_store_vault_id
    secrets_store_key_id               = var.secrets_store_key_id
  }
  ssh_authorized_keys = "${var.ssh_public_key}\n${data.external.builder_ssh_key_to_vault.result.public_key}"
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
    oci_profile            = var.oci_profile
    compartment_id         = var.secrets_store_vault_compartment_id
    secrets_store_vault_id = var.secrets_store_vault_id
    secrets_store_key_id   = var.secrets_store_key_id
    secret_name            = "${local.deploy_id}_LANGFUSE_BUILDER_PRIVATE_KEY"
  }
}

output "builder_public_key" {
  value = data.external.builder_ssh_key_to_vault.result
}


module "builder_setup_shell_stage" {
  source                = "./modules/devops/deployment_stages/shell_stage"
  compartment_id        = local.devops_compartment_id
  subnet_id             = var.use_existing_vcn ? local.node_pools[0]["subnet"] : oci_core_subnet.oke_nodepool_subnet[0].id
  stage_name            = "builder_setup"
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
  command_spec_content = file("./scripts/command_spec.yaml")
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

