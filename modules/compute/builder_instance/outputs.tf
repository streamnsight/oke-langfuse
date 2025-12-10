output "details" {
  value = {
    instance_id = oci_core_instance.builder.id,
    private_key = tls_private_key.public_private_key_pair.private_key_openssh
    ip_address  = oci_core_instance.builder.public_ip
  }
}