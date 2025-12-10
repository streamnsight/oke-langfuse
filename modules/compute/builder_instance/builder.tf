resource "tls_private_key" "public_private_key_pair" {
  algorithm = "RSA"
}

resource "oci_core_instance" "builder" {
  #Required
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.compute_shape

  create_vnic_details {
    #Optional
    assign_ipv6ip    = false
    assign_public_ip = true
    display_name     = var.display_name
    subnet_id        = var.subnet_id
  }

  display_name      = var.display_name
  extended_metadata = var.metadata
  metadata = {
    "ssh_authorized_keys" = "${var.ssh_authorized_keys}\n${tls_private_key.public_private_key_pair.public_key_openssh}"
  }
  dynamic "shape_config" {
    for_each = length(regexall("Flex", var.compute_shape)) > 0 ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory
    }
  }
  source_details {
    #Required
    source_id   = var.image_id
    source_type = "image"

    #Optional
    boot_volume_size_in_gbs = var.boot_volume_gb
    boot_volume_vpus_per_gb = 10
  }
  preserve_boot_volume = false
}

# Policy for this builder instance
module "builder_policy" {
  source         = "../../iam/policy"
  compartment_id = var.compartment_id
  description    = "policy for ${var.display_name} builder"
  policy_statements = [for statement in var.policies :
    "allow any-user to ${statement} in compartment id ${var.compartment_id} where ALL { request.principal.id = '${oci_core_instance.builder.id}' }"
  ]
}
