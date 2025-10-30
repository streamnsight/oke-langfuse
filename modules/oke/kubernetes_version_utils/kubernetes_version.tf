variable "kubernetes_version" {
  type    = string
  default = null
}

data "oci_containerengine_cluster_option" "cluster_options" {
  cluster_option_id = "all"
}

locals {
  is_not_provided    = var.kubernetes_version == null || var.kubernetes_version == ""
  trimmed_version    = local.is_not_provided ? null : replace(var.kubernetes_version, "v", "")
  has_minor          = length(split(".", local.trimmed_version)) > 2
  available_versions = [for v in data.oci_containerengine_cluster_option.cluster_options.kubernetes_versions : replace(v, "v", "")]
  numerically_sorted_versions = [
    for x in reverse(sort([
      for v in distinct(compact(concat(local.available_versions, [local.trimmed_version]))) :
      join(".", [for w in split(".", v) : format("%03d", w)])
    ])) :
    join(".", [for y in split(".", x) : tonumber(y)])
  ]
  is_available   = local.is_not_provided ? null : contains(local.available_versions, local.trimmed_version)
  latest_version = reverse(local.available_versions)[0]
  # index of the closest version, when the provided version is not in the available versions
  # pick the version above if not higher than the highest, if it is (i.e. = 0), pick the latest, which is index 1
  index               = local.is_not_provided ? 0 : index(local.numerically_sorted_versions, local.trimmed_version) == 0 ? 1 : index(local.numerically_sorted_versions, local.trimmed_version) - 1
  closest_version     = local.is_not_provided ? local.latest_version : local.is_available ? local.trimmed_version : element(local.numerically_sorted_versions, local.index)
  selected_version    = local.is_not_provided ? local.latest_version : local.closest_version
  semver              = split(".", replace(local.selected_version, "v", ""))
  major_version       = tonumber(local.semver[1])
  minor_version       = tonumber(local.semver[2])
  major_minor_version = join(".", slice(local.semver, 0, 2))
}

output "versions" {
  value = {
    # numerically_sorted_versions = local.numerically_sorted_versions
    available    = local.available_versions
    is_available = local.is_available
    has_minor    = local.has_minor
    latest       = local.latest_version
    closest      = local.closest_version
    selected     = local.selected_version
    semver       = local.semver
    major        = local.major_version
    minor        = local.minor_version
    major_minor  = local.major_minor_version
  }
}
