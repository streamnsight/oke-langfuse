## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

module "test1" {
  source             = "../../recommended-compute-image"
  image_id           = "ocid1.image.oc1.us-sanjose-1.aaaaaaaahjftpvjnl3cawwwz34de5zqbbi3iz5cugbl2f5neehimxtzbjhrq"
  kubernetes_version = "v1.34.1"
}

output "result" {
  value = var.image_id != module.test1.recommended_image_id && regex("ocid1.image", module.test1.recommended_image_id) == "ocid1.image"
}
