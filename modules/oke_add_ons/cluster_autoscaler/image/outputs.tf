output "k8s_major_minor" {
  value = local.k8s_major_minor
}

output "k8s_major" {
  value = local.k8s_major
}

output "ca_image" {
  value = local.image_tag != null ? "${var.ocir_region}.ocir.io/oracle/oci-cluster-autoscaler:${local.image_tag}" : null
}

output "ca_provider" {
  value = local.k8s_major <= 23 || local.k8s_major > 26 ? "oci" : "oci-oke"
}

output "tag" {
  value = local.image_tag
}

output "ca_image_version" {
  value = local.image_version
}