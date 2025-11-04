module "bastion" {
  count                                = var.is_endpoint_public ? 0 : 1
  source                               = "./modules/compute/bastion"
  compartment_id                       = var.cluster_compartment_id
  subnet_id                            = var.use_existing_vcn ? var.kubernetes_endpoint_subnet : oci_core_subnet.oke_api_endpoint_subnet[0].id
  bastion_client_cidr_block_allow_list = ["0.0.0.0/0"]
  bastion_name                         = local.cluster_name_sanitized
}

resource "tls_private_key" "bastion_session_public_private_key_pair" {
  algorithm = "RSA"
}

resource "oci_bastion_session" "installer_session" {
  count = var.is_endpoint_public ? 0 : 1
  #Required
  bastion_id = module.bastion[0].id
  key_details {
    #Required
    public_key_content = tls_private_key.bastion_session_public_private_key_pair.public_key_openssh
  }
  target_resource_details {
    #Required
    session_type = "DYNAMIC_PORT_FORWARDING" # "PORT_FORWARDING"

    #Optional
    target_resource_port               = local.cluster_endpoint_port
    target_resource_private_ip_address = local.cluster_endpoint_host
  }

  #Optional
  display_name           = "k8sAPI_for_RMS_install"
  key_type               = "PUB"
  session_ttl_in_seconds = 1800

}