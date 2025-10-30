
module "create_repo" {
  source         = "../create_repo"
  repo_name      = "${var.oss_charts_repo_prefix}/${var.chart["repo_name"]}/${var.chart["chart_name"]}"
  compartment_id = var.compartment_id
}

resource "null_resource" "push_chart" {
  triggers = {
    versions    = var.chart["chart_version"]
    repo_prefix = var.oss_charts_repo_prefix
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add ${var.chart["repo_name"]} ${var.chart["repo_url"]} --force-update \
      && helm pull ${var.chart["repo_name"]}/${var.chart["chart_name"]} --version ${var.chart["chart_version"]} \
      && oci raw-request --profile ${var.oci_profile} --http-method GET --target-uri https://${var.region}.ocir.io/20180419/docker/token | jq -r .data.token | helm registry login ${var.region}.ocir.io -u BEARER_TOKEN --password-stdin \
      && helm push ${var.chart["chart_name"]}-${var.chart["chart_version"]}.tgz oci://${var.region}.ocir.io/${var.object_storage_namespace}/${var.oss_charts_repo_prefix}/${var.chart["repo_name"]} \
      && rm -f ${var.chart["chart_name"]}-${var.chart["chart_version"]}.tgz
    EOT
    # on_failure = continue
  }
  depends_on = [module.create_repo]
}
