## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "details" {
  value = {
    instance_id = oci_core_instance.builder.id,
    private_key = tls_private_key.public_private_key_pair.private_key_openssh
    ip_address  = oci_core_instance.builder.public_ip
    private_ip  = oci_core_instance.builder.private_ip
  }
}
