
resource "null_resource" "deploy_load_balancer_no_tls" {
  triggers = {
    file = file("${path.module}/../manifests/langfuse_no_tls.Ingress.yaml")
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
    source      = "${path.module}/../manifests/langfuse_no_tls.Ingress.yaml"
    destination = "/home/opc/langfuse_no_tls.Ingress.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/../manifests/nginx-ingress-controller.yaml"
    destination = "/home/opc/nginx-ingress-controller.yaml"
  }

  provisioner "remote-exec" {
    when = create
    # wrap the inline script into a template script file so the file content can be used as a trigger 
    # and this runs each time the script changes
    inline = [<<EOF
        # deploy nginx ingress controller
        kubectl apply -f nginx-ingress-controller.yaml
        # https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.1/deploy/static/provider/cloud/deploy.yaml
        # deploy our ingress
        kubectl get namespace langfuse || kubectl create namespace langfuse
        kubectl apply -f langfuse_no_tls.Ingress.yaml --namespace langfuse
    EOF
    ]
  }
}


data "oci_load_balancer_load_balancers" "load_balancers" {
  #Required
  compartment_id = var.compartment_id

  #Optional
  detail = "full"
  # display_name = "langfuse-web-${local.deploy_id}"

  depends_on = [null_resource.deploy_load_balancer_no_tls]
}
