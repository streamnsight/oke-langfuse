## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

output "manifest_yaml" {
  value = local.manifest_yaml
}

output "pipeline_id" {
  value = oci_devops_deploy_pipeline.oci_genai_gateway.id
}

output "deployment_id" {
  value = oci_devops_deployment.oci_genai_gateway_deployment.id
}

output "stage_id" {
  value = oci_devops_deploy_stage.oci_genai_gateway.id
}

# output "default_api_key" {
#   value = random_string.oci_genai_gateway_default_api_key.result
# }
