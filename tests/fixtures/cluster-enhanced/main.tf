resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

resource "tls_private_key" "generated" {
  count     = var.ssh_public_key == null ? 1 : 0
  algorithm = "RSA"
}

data "terraform_remote_state" "network" {
  backend = "local"

  config = {
    path = "${path.module}/../network/terraform.tfstate"
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

module "cloud_init_script" {
  source = "../../../modules/oke/cloud_init_script"
}

module "recommended_image" {
  source             = "../../../modules/oke/recommended-compute-image"
  image_id           = var.fixture_node_image_id
  kubernetes_version = var.kubernetes_version
}

locals {
  cluster_name        = "${var.cluster_name}-${random_string.suffix.result}"
  availability_domain = coalesce(var.fixture_availability_domain, data.oci_identity_availability_domains.ads.availability_domains[0].name)
  node_pool_subnet_id = data.terraform_remote_state.network.outputs.node_pool_subnet_ids_by_name["np1"]
  ssh_authorized_key  = var.ssh_public_key != null ? var.ssh_public_key : tls_private_key.generated[0].public_key_openssh
}

resource "oci_containerengine_cluster" "enhanced" {
  compartment_id     = var.cluster_compartment_id
  kubernetes_version = var.kubernetes_version
  name               = local.cluster_name
  vcn_id             = data.terraform_remote_state.network.outputs.vcn_id
  type               = "ENHANCED_CLUSTER"
  defined_tags       = var.defined_tags

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  endpoint_config {
    is_public_ip_enabled = var.is_public_endpoint
    subnet_id            = data.terraform_remote_state.network.outputs.kubernetes_endpoint_subnet_id
  }

  options {
    service_lb_subnet_ids = [data.terraform_remote_state.network.outputs.public_lb_subnet_id]

    kubernetes_network_config {
      pods_cidr     = var.pods_cidr
      services_cidr = var.services_cidr
    }
  }

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_containerengine_node_pool" "primary" {
  cluster_id         = oci_containerengine_cluster.enhanced.id
  compartment_id     = var.cluster_compartment_id
  kubernetes_version = var.kubernetes_version
  name               = "primary-${var.node_pool_size}"
  node_shape         = var.node_shape
  ssh_public_key     = local.ssh_authorized_key
  defined_tags       = var.defined_tags
  node_metadata      = var.use_custom_cloud_init ? module.cloud_init_script.content : {}

  node_source_details {
    image_id                = module.recommended_image.recommended_image_id
    source_type             = "IMAGE"
    boot_volume_size_in_gbs = var.node_boot_volume_size_gb
  }

  node_config_details {
    placement_configs {
      availability_domain = local.availability_domain
      subnet_id           = local.node_pool_subnet_id
    }

    node_pool_pod_network_option_details {
      cni_type       = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids = [local.node_pool_subnet_id]
    }

    size = var.node_pool_size
  }

  dynamic "node_shape_config" {
    for_each = length(regexall("Flex", var.node_shape)) > 0 ? [1] : []
    content {
      ocpus         = var.node_shape_ocpus
      memory_in_gbs = var.node_shape_memory_gb
    }
  }

  node_eviction_node_pool_settings {
    eviction_grace_duration              = "PT10M"
    is_force_delete_after_grace_duration = true
  }

  node_pool_cycling_details {
    is_node_cycling_enabled = true
    maximum_surge           = 1
    maximum_unavailable     = 1
  }

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

module "bastion" {
  count          = var.create_bastion ? 1 : 0
  source         = "../../../modules/compute/bastion"
  compartment_id = var.cluster_compartment_id
  subnet_id      = data.terraform_remote_state.network.outputs.kubernetes_endpoint_subnet_id
  bastion_name   = "${local.cluster_name}-bastion"
}
