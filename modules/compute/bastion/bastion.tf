resource "oci_bastion_bastion" "bastion" {
  #Required
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_id
  target_subnet_id = var.subnet_id

  #Optional
  client_cidr_block_allow_list = var.bastion_client_cidr_block_allow_list
  #defined_tags = {"foo-namespace.bar-key"= "value"}
  dns_proxy_status = "ENABLED"
  #freeform_tags = {"bar-key"= "value"}
  #max_session_ttl_in_seconds = var.bastion_max_session_ttl_in_seconds
  name = var.bastion_name
  #phone_book_entry = var.bastion_phone_book_entry
  #static_jump_host_ip_addresses = var.bastion_static_jump_host_ip_addresses
}

output "id" {
  value = oci_bastion_bastion.bastion.id
}