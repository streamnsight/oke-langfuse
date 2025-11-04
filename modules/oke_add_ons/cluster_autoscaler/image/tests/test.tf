module "test1" {
  source             = "../../image"
  kubernetes_version = "v1.26.2"
}

output "result1a" {
  value = module.test1.k8s_major_minor == "1.26"
}
output "result1b" {
  value = module.test1.k8s_major == 26
}
output "result1c" {
  value = module.test1.ca_image == "us-ashburn-1.ocir.io/oracle/oci-cluster-autoscaler:1.26.2-11"
}
output "result1d" {
  value = module.test1.ca_provider == "oci-oke"
}

# set region to valid region
module "test2" {
  source             = "../../image"
  kubernetes_version = "v1.27.2"
  ocir_region        = "uk-london-1"
}
output "result2a" {
  value = module.test2.ca_image == "uk-london-1.ocir.io/oracle/oci-cluster-autoscaler:1.27.2-9"
}
output "result2b" {
  value = module.test2.ca_provider == "oci"
}

# set region to invalid region
module "test3" {
  source             = "../../image"
  kubernetes_version = "v1.26.2"
  ocir_region        = "us-sanjose-1"
}
output "result3a" {
  value = module.test3.ca_image == null
}

# set version to invalid version
module "test4" {
  source             = "../../image"
  kubernetes_version = "v1.35.2"
}
output "result4a" {
  value = module.test4.ca_image == null
}

# set version to older version
module "test5" {
  source             = "../../image"
  kubernetes_version = "1.23.2"
}
output "result5a" {
  value = module.test5.ca_image == "us-ashburn-1.ocir.io/oracle/oci-cluster-autoscaler:1.23.0-4"
}
output "result5b" {
  value = module.test5.ca_provider == "oci"
}
