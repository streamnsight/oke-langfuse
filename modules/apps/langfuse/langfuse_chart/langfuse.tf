
# build the OCI GenAI Gateway image
resource "null_resource" "build_image" {
  triggers = {
    instance_id = var.builder_details.instance_id
    script_sha  = sha256(file("./scripts/build_image.sh"))
  }
  connection {
    type        = "ssh"
    user        = "opc"
    private_key = module.builder.details.private_key
    host        = module.builder.details.ip_address
  }

  provisioner "file" {
    source      = "./scripts/build_image.sh"
    destination = "/home/opc/build_image.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/opc/build_image.sh",
      "/home/opc/build_image.sh",
    ]
  }
}
