locals {
  kubernetes_version     = "v${module.kubernetes_version.versions.selected}"
  cluster_name           = "${substr(var.cluster_name, 0, 200)}-${random_string.deploy_id.result}"
  cluster_name_sanitized = replace(local.cluster_name, " ", "_")
}