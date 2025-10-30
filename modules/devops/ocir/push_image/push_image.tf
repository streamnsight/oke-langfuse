module "create_repo" {
  source         = "../create_repo"
  repo_name      = var.repo["dest_repo"]
  compartment_id = var.compartment_id
}

resource "null_resource" "push_image" {
  triggers = {
    images      = var.repo["version"]
    repo_prefix = var.oss_images_repo_prefix
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker pull ${var.repo["src_registry"]}/${var.repo["repo"]}:${var.repo["version"]} \
      && docker tag ${var.repo["src_registry"]}/${var.repo["repo"]}:${var.repo["version"]} ${var.repo["dest_registry"]}/${var.repo["dest_ns"]}/${var.repo["dest_repo"]}:${var.repo["version"]} \
      && oci raw-request --profile ${var.oci_profile} --http-method GET --target-uri https://${var.region}.ocir.io/20180419/docker/token | jq -r .data.token | docker login ${var.region}.ocir.io -u BEARER_TOKEN --password-stdin \
      && docker push ${var.repo["dest_registry"]}/${var.repo["dest_ns"]}/${var.repo["dest_repo"]}:${var.repo["version"]}
    EOT
    # on_failure = continue
  }
  depends_on = [module.create_repo]
}
