output "repos" {
  value = local.repos
}

output "stage" {
  value = oci_devops_deploy_stage.metrics-server
}