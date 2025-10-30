resource "oci_devops_deploy_environment" "oke_cluster" {
  count      = var.target_cluster == null ? 0 : 1
  cluster_id = var.target_cluster.id
  #compute_instance_group_selectors = <<Optional value not found in discovery>>
  deploy_environment_type = "OKE_CLUSTER"
  description             = var.target_cluster.name
  display_name            = var.target_cluster.name
  defined_tags            = var.defined_tags
  #function_id = <<Optional value not found in discovery>>
  network_channel {
    network_channel_type = "PRIVATE_ENDPOINT_CHANNEL"
    nsg_ids              = var.target_cluster.endpoint_config[0].nsg_ids
    subnet_id            = var.target_cluster.endpoint_config[0].subnet_id
  }
  project_id = var.project_id
  timeouts {
    create = "15m"
  }
  lifecycle {
    ignore_changes = [defined_tags]
  }
}

