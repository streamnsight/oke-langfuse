# check if repo exists
# data "oci_artifacts_container_repositories" "repo_exists" {
#   compartment_id = var.compartment_id
#   display_name   = var.repo_name
# }

# If not present, create it. 
resource "oci_artifacts_container_repository" "image_repo" {
  # this doesn't work because at each apply the count switchs between 0 and 1, deleting the repo
  # count          = data.oci_artifacts_container_repositories.repo_exists.container_repository_collection[0].repository_count == 0 ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = var.repo_name
  is_immutable   = "false"
  is_public      = "false"

}
