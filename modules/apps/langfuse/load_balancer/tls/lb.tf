
resource "null_resource" "create_langfuse_lb_tls" {
  triggers = {
    file = file("${path.module}/../manifests/langfuse_tls.Ingress.yaml")
  }
  # TODO 
  # create the public load balancer via k8s Service, 
  # fetch the IP, 
  # create the certificate for the LB based on IP, 
  # update the helm chart value for LANGFUSE_HOSTNAME
  # update the IDCS app with the URL for login redirect
  connection {
    type        = "ssh"
    user        = "opc"
    private_key = var.builder_details.private_key
    host        = var.builder_details.ip_address
  }

  provisioner "file" {
    source      = "${path.module}/../manifests/langfuse_tls.Ingress.yaml"
    destination = "/home/opc/langfuse_tls.Ingress.yaml"
  }


  provisioner "remote-exec" {
    when = create
    # wrap the inline script into a template script file so the file content can be used as a trigger 
    # and this runs each time the script changes
    inline = [<<EOF
        sed -i 's|$LANGFUSE_HOSTNAME|${var.langfuse_hostname}|gm' langfuse_tls.Ingress.yaml
        kubectl apply -f langfuse_tls.Ingress.yaml --namespace langfuse
    EOF
    ]
  }

}


