## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "pipeline_id" {
  value = module.build_langfuse_image_shell_stage.pipeline_id
}

output "deployment_id" {
  value = module.build_langfuse_image_shell_stage.deployment_id
}

output "stage_id" {
  value = module.build_langfuse_image_shell_stage.stage_id
}
