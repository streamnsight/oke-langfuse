resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

data "terraform_remote_state" "network" {
  backend = "local"

  config = {
    path = "${path.module}/../network/terraform.tfstate"
  }
}

locals {
  cluster_name = "${var.cluster_name}-${random_string.suffix.result}"
}

resource "oci_containerengine_cluster" "basic" {
  compartment_id     = var.cluster_compartment_id
  kubernetes_version = var.kubernetes_version
  name               = local.cluster_name
  vcn_id             = data.terraform_remote_state.network.outputs.vcn_id
  type               = "BASIC_CLUSTER"
  defined_tags       = var.defined_tags

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  endpoint_config {
    is_public_ip_enabled = false
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

module "bastion" {
  count          = var.create_bastion ? 1 : 0
  source         = "../../../modules/compute/bastion"
  compartment_id = var.cluster_compartment_id
  subnet_id      = data.terraform_remote_state.network.outputs.kubernetes_endpoint_subnet_id
  bastion_name   = "${local.cluster_name}-bastion"
}
