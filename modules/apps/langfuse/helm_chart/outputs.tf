## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "pipeline_id" {
  value = oci_devops_deploy_pipeline.langfuse.id
}

output "deployment_id" {
  value = oci_devops_deployment.langfuse_deployment.id
}

output "stage_id" {
  value = oci_devops_deploy_stage.langfuse.id
}
