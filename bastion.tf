## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

module "bastion" {
  count                                = var.is_endpoint_public ? 0 : var.create_bastion ? 1 : 0
  source                               = "./modules/compute/bastion"
  compartment_id                       = var.cluster_compartment_id
  subnet_id                            = var.use_existing_vcn ? var.kubernetes_endpoint_subnet : oci_core_subnet.oke_api_endpoint_subnet[0].id
  bastion_client_cidr_block_allow_list = ["0.0.0.0/0"]
  bastion_name                         = local.cluster_name_sanitized
}
