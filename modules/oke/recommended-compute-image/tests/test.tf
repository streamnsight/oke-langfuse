module "test1" {
  source             = "../../recommended-compute-image"
  image_id           = "ocid1.image.oc1.us-sanjose-1.aaaaaaaahjftpvjnl3cawwwz34de5zqbbi3iz5cugbl2f5neehimxtzbjhrq"
  kubernetes_version = "v1.26.7"
}

output "result" {
  value = var.image_id != module.test1.recommended_image_id && regex("ocid1.image", module.test1.recommended_image_id) == "ocid1.image"
}
