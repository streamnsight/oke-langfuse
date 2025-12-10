
# build the OCI GenAI Gateway image
resource "null_resource" "build_image" {
  triggers = {
    instance_id = var.builder_details.instance_id
    script_sha  = sha256(file("${path.module}/scripts/build_langfuse_image.sh"))
  }
  connection {
    type        = "ssh"
    user        = "opc"
    private_key = var.builder_details.private_key
    host        = var.builder_details.ip_address
  }

  provisioner "file" {
    source      = "${path.module}/scripts/build_langfuse_image.sh"
    destination = "/home/opc/build_langfuse_image.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/opc/build_langfuse_image.sh",
      "/home/opc/build_langfuse_image.sh",
    ]
  }
}
