locals {
  # list of cluster autoscaler image tags in the OCIR region
  # tags = jsondecode(data.local_file.cluster_autoscaler_image_tags.content)

  # semantic major/minor kubernetes version from full version
  k8s_version_array = split(".", replace(var.kubernetes_version, "v", ""))
  k8s_major_minor   = join(".", slice(local.k8s_version_array, 0, 2))
  k8s_major         = tonumber(local.k8s_version_array[1])
  # regex pattern of the image tags
  tag_regex = "[0-9]+[.][0-9]+[.][0-9]+[-][0-9]+"

  # image tags matching the kubernetes major/minor semver
  # image_tags = tolist(toset(compact([for tag in local.tags :
  #   length(regexall(local.k8s_major_minor, tag)) > 0 ? regex(local.tag_regex, tag) : null
  # ])))
  # latest version of the image for this kubernetes semver
  # image_tags_latest_version = length(local.image_tags) > 0 ? tostring([for t in reverse(sort([for v in local.image_tags : format("%03d", tonumber(split("-", v)[1]))])) : tonumber(t)][0]) : null
  # image_tag                 = local.image_tags_latest_version != null ? compact([for t in local.image_tags : split("-", t)[1] == local.image_tags_latest_version ? t : null])[0] : null

  image_tag     = data.external.cluster_autoscaler_image_tag.result["image"] != "-" ? data.external.cluster_autoscaler_image_tag.result["image"] : null
  image_version = data.external.cluster_autoscaler_image_tag.result["image"] != "-" ? "v${split("-", data.external.cluster_autoscaler_image_tag.result["image"])[0]}" : null
}

# resource "null_resource" "cluster_autoscaler_images_tags" {

#   triggers = {
#     region = var.ocir_region
#   }
#   provisioner "local-exec" {
#     command = "oci raw-request --http-method GET --target-uri https://${var.ocir_region}.ocir.io/v2/oracle/oci-cluster-autoscaler/tags/list | jq '.data | .tags // []' > ${path.module}/ca_image_tags.${var.ocir_region}.json"
#   }

#   provisioner "local-exec" {
#     when    = destroy
#     command = "printf ${path.module}/${self.id}"
#   }
# }

data "external" "cluster_autoscaler_image_tag" {
  program = ["bash", "${path.module}/get_image_tag.sh"]
  query = {
    ocir_region        = var.ocir_region
    kubernetes_version = local.k8s_major_minor
  }
}

# data "local_file" "cluster_autoscaler_image_tags" {
#   filename   = "${path.module}/ca_image_tags.${var.ocir_region}.json"
#   depends_on = [null_resource.cluster_autoscaler_images_tags]
# }

