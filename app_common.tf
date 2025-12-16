module "builder_instance" {
  source              = "./modules/compute/builder_instance"
  compartment_id      = var.cluster_compartment_id
  availability_domain = local.ADs[0]
  subnet_id           = var.use_existing_vcn ? var.public_lb_subnet : oci_core_subnet.oke_lb_subnet[0].id
  display_name        = "${local.cluster_name_sanitized}-builder"
  compute_shape       = local.node_pools[0].node_shape
  image_id            = local.node_pools[0].image_id
  metadata = {
    deploy_id                   = local.deploy_id
    cluster_id                  = oci_containerengine_cluster.oci_oke_cluster.id
    langfuse_helm_chart_version = var.langfuse_helm_chart_version
  }
  ssh_authorized_keys = var.ssh_public_key
  policies = [
    "manage repos",
    "manage instance-family",
    "manage cluster-family"
  ]

  providers = {
    oci             = oci
    oci.home_region = oci.home_region
  }
}


resource "null_resource" "builder_setup" {
  triggers = {
    instance_id        = module.builder_instance.details.instance_id
    script_sha         = sha256(file("./scripts/install_dependencies.sh"))
    helm_chart_version = var.langfuse_helm_chart_version
  }
  connection {
    type        = "ssh"
    user        = "opc"
    private_key = module.builder_instance.details.private_key
    host        = module.builder_instance.details.ip_address
  }

  provisioner "file" {
    source      = "./scripts/install_dependencies.sh"
    destination = "/home/opc/install_dependencies.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/opc/install_dependencies.sh",
      "/home/opc/install_dependencies.sh",
    ]
  }

}


# output "builder" {
#   value     = module.builder_instance.details
#   sensitive = true
# }