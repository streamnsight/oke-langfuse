
# build the OCI GenAI Gateway image
resource "null_resource" "build_image" {
  triggers = {
    instance_id = var.builder_details.instance_id
    script_sha  = sha256(file("${path.module}/scripts/build_oci_genai_gateway_image.sh"))
  }
  connection {
    type        = "ssh"
    user        = "opc"
    private_key = var.builder_details.private_key
    host        = var.builder_details.ip_address
  }

  provisioner "file" {
    source      = "${path.module}/scripts/build_oci_genai_gateway_image.sh"
    destination = "/home/opc/build_oci_genai_gateway_image.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/opc/build_oci_genai_gateway_image.sh",
      "/home/opc/build_oci_genai_gateway_image.sh",
    ]
  }
}


resource "random_string" "oci_genai_gateway_default_api_key" {
  length      = 56
  special     = false
  min_lower   = 2
  min_upper   = 2
  min_numeric = 4
}

# create the kubernetes secret
resource "null_resource" "create_oci_genai_gateway_secrets" {
  triggers = {
    instance_id      = var.builder_details.instance_id
    script           = file("${path.module}/scripts/create_oci_genai_gateway_secrets.sh")
    default_api_keys = random_string.oci_genai_gateway_default_api_key.result
  }
  connection {
    type        = "ssh"
    user        = "opc"
    private_key = var.builder_details.private_key
    host        = var.builder_details.ip_address
  }

  provisioner "remote-exec" {
    # wrap the inline script into a template script file so the file content can be used as a trigger 
    # and this runs each time the script changes
    inline = [<<EOF
            ${templatefile("${path.module}/scripts/create_oci_genai_gateway_secrets.sh", {
      default_api_keys = random_string.oci_genai_gateway_default_api_key.result
})}
        EOF
]
}
}
