
# basic test
module "test1" {
  source             = "../"
  kubernetes_version = "v1.26.7"
}
output "result1a" {
  value = module.test1.versions.selected == "1.26.7"
}
output "result1b" {
  value = module.test1.versions.major == 26
}
output "result1c" {
  value = module.test1.versions.minor == 7
}
output "result1d" {
  value = module.test1.versions.major_minor == "1.26"
}
output "result1e" {
  value = join("#", module.test1.versions.semver) == "1#26#7"
}

module "test3" {
  source             = "../"
  kubernetes_version = "v1.27.2"
}
output "result3" {
  value = module.test3.versions.selected == "1.27.2"
}

# version higher than available
module "test4" {
  source             = "../"
  kubernetes_version = "v1.35.12"
}
output "result4" {
  value = module.test4.versions.selected == module.test4.versions.latest # latest if version higher than available
}

# version lower than available
module "test5" {
  source             = "../"
  kubernetes_version = "v1.24.3"
}
output "result5" {
  value = module.test5.versions.selected == module.test5.versions.available[0] # earliest version
}

# null input produces latest version
module "test6" {
  source             = "../"
  kubernetes_version = null
}
output "result6" {
  value = module.test6.versions.selected == module.test6.versions.latest # latest version if null
}

# empty input produces latest version
module "test7" {
  source             = "../"
  kubernetes_version = ""
}
output "result7" {
  value = module.test7.versions.selected == module.test7.versions.latest # latest version if empty
}

module "test8" {
  source             = "../"
  kubernetes_version = "1.26"
}
output "result8" {
  value = module.test8.versions.selected == "1.26.7"
}
