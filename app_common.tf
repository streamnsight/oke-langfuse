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
}


# resource "oci_core_instance" "langfuse_builder" {
#   #Required
#   availability_domain = local.ADs[0]
#   compartment_id      = var.cluster_compartment_id
#   shape               = local.node_pools[0].node_shape

#   create_vnic_details {

#     #Optional
#     assign_ipv6ip    = false
#     assign_public_ip = true
#     display_name     = "${local.cluster_name_sanitized}-builder"

#     subnet_id = var.use_existing_vcn ? var.public_lb_subnet : oci_core_subnet.oke_lb_subnet[0].id
#   }
#   display_name = "${local.cluster_name_sanitized}-builder"
#   extended_metadata = {
#     deploy_id                   = local.deploy_id
#     cluster_id                  = oci_containerengine_cluster.oci_oke_cluster.id
#     langfuse_helm_chart_version = var.langfuse_helm_chart_version
#   }
#   metadata = {
#     "ssh_authorized_keys" = "${var.ssh_public_key}\n${tls_private_key.bastion_session_public_private_key_pair.public_key_openssh}"
#   }
#   dynamic "shape_config" {
#     for_each = length(regexall("Flex", local.node_pools[0]["node_shape"])) > 0 ? [1] : []
#     content {
#       ocpus         = 4
#       memory_in_gbs = 24
#     }
#   }
#   source_details {
#     #Required
#     source_id   = local.node_pools[0].image_id
#     source_type = "image"

#     #Optional
#     boot_volume_size_in_gbs = 100
#     boot_volume_vpus_per_gb = 10
#   }
#   preserve_boot_volume = false
# }

# # Policy for this builder instance
# module "builder_policy" {
#   source         = "./modules/iam/policy"
#   compartment_id = var.cluster_compartment_id
#   description    = "policy for ${local.deploy_id} builder"
#   policy_statements = [
#     "allow any-user to manage repos in compartment id ${var.cluster_compartment_id} where ALL { request.principal.id = '${oci_core_instance.langfuse_builder.id}' }",
#     "allow any-user to manage instance-family in compartment id ${var.cluster_compartment_id} where ALL { request.principal.id = '${oci_core_instance.langfuse_builder.id}' }",
#     "allow any-user to manage cluster-family in compartment id ${var.cluster_compartment_id} where ALL { request.principal.id = '${oci_core_instance.langfuse_builder.id}' }",
#   ]
# }

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



# resource "null_resource" "builder_run" {
#   triggers = {
#     instance_id = oci_core_instance.langfuse_builder.id
#     script_sha  = sha256(file("./scripts/build_images.sh"))
#     helm_chart_version = var.langfuse_helm_chart_version
#   }
#   connection {
#     type        = "ssh"
#     user        = "opc"
#     private_key = tls_private_key.bastion_session_public_private_key_pair.private_key_openssh
#     host        = oci_core_instance.langfuse_builder.public_ip
#   }

#   provisioner "file" {
#     source      = "./scripts/build_images.sh"
#     destination = "/home/opc/build_images.sh"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "chmod +x /home/opc/build_images.sh",
#       "/home/opc/build_images.sh",
#     ]
#   }
#   depends_on = [module.builder_policy]
# }

# resource "random_string" "oci_genai_gateway_default_api_key" {
#   length      = 20
#   special     = false
#   min_lower   = 2
#   min_upper   = 2
#   min_numeric = 4
# }

# resource "null_resource" "create_oci_genai_gateway_secrets" {
#   triggers = {
#     instance_id      = oci_core_instance.langfuse_builder.id
#     script           = file("./scripts/create_oci_genai_gateway_secrets.sh")
#     default_api_keys = random_string.oci_genai_gateway_default_api_key.result
#   }
#   connection {
#     type        = "ssh"
#     user        = "opc"
#     private_key = tls_private_key.bastion_session_public_private_key_pair.private_key_openssh
#     host        = oci_core_instance.langfuse_builder.public_ip
#   }

#   provisioner "remote-exec" {
#     # wrap the inline script into a template script file so the file content can be used as a trigger 
#     # and this runs each time the script changes
#     inline = [<<EOF
#             ${templatefile("./scripts/create_oci_genai_gateway_secrets.sh", {
#       default_api_keys = random_string.oci_genai_gateway_default_api_key.result
# })}
#         EOF
# ]
# }
# depends_on = [
#   null_resource.builder_run,
#   oci_containerengine_node_pool.oci_oke_node_pool,
# ]
# }

# Langfuse 

# resource "random_string" "langfuse_password_encryption_key" {
#   length      = 64
#   special     = false
#   min_lower   = 2
#   min_upper   = 2
#   min_numeric = 4
# }

# resource "random_string" "langfuse_password_encryption_salt" {
#   length      = 24
#   special     = false
#   min_lower   = 2
#   min_upper   = 2
#   min_numeric = 4
# }

# resource "random_string" "langfuse_next_auth_secret" {
#   length      = 48
#   special     = false
#   min_lower   = 2
#   min_upper   = 2
#   min_numeric = 4
# }

# resource "random_string" "langfuse_clickhouse_password" {
#   length      = 24
#   special     = false
#   min_lower   = 2
#   min_upper   = 2
#   min_numeric = 4
# }

# resource "random_string" "langfuse_redis_password" {
#   length      = 24
#   special     = false
#   min_lower   = 2
#   min_upper   = 2
#   min_numeric = 4
# }

# creates secrets for langfuse. We don't want these coded into a manifest stored in artifacts, 
# or passing secrets as ENV variables to a build step
# so this ensures secrets are created without leaving the 
# resource "null_resource" "create_langfuse_secrets" {
#   triggers = {
#     instance_id         = oci_core_instance.langfuse_builder.id
#     script              = file("./scripts/create_langfuse_secrets.sh")
#     encryption_key      = random_string.langfuse_password_encryption_key.result
#     salt                = random_string.langfuse_password_encryption_salt.result
#     nextauth_secret     = random_string.langfuse_next_auth_secret.result
#     clickhouse_password = random_string.langfuse_clickhouse_password.result
#     redis_password      = random_string.langfuse_redis_password.result
#     postgres_password   = random_string.postgres_password.result
#     app_id = local.idcs_app_id #var.idcs_app_id
#   }
#   connection {
#     type        = "ssh"
#     user        = "opc"
#     private_key = tls_private_key.bastion_session_public_private_key_pair.private_key_openssh
#     host        = oci_core_instance.langfuse_builder.public_ip
#   }

#   provisioner "file" {
#     source      = "CaCertificate-langfuse.pub"
#     destination = "/home/opc/CaCertificate-langfuse.pub"
#   }

#   provisioner "remote-exec" {
#     when = create
#     # wrap the inline script into a template script file so the file content can be used as a trigger 
#     # and this runs each time the script changes
#     inline = [
#     <<EOF
#             ${templatefile("./scripts/create_langfuse_secrets.sh", {
#             encryption_key      = random_string.langfuse_password_encryption_key.result
#             salt                = random_string.langfuse_password_encryption_salt.result
#             nextauth_secret     = random_string.langfuse_next_auth_secret.result
#             clickhouse_password = random_string.langfuse_clickhouse_password.result
#             redis_password      = random_string.langfuse_redis_password.result
#             client_id           = local.idcs_client_id
#             client_secret       = local.idcs_client_secret
#             issuer              = local.idcs_domain_url
#             s3_access_key       = var.langfuse_s3_access_key
#             s3_secret_key       = var.langfuse_s3_secret_key
#             postgres_password   = random_string.postgres_password.result
#             database_url        = "postgresql://langfuse:${random_string.postgres_password.result}@${local.psql_endpoint.fqdn}:${local.psql_endpoint.port}/postgres?sslmode=verify-full&sslrootcert=/secrets/db-keystore/CaCertificate-langfuse.pub"
#         })}
#     EOF
#     ]
#   }


#     depends_on = [
#         null_resource.builder_run,
#         oci_containerengine_node_pool.oci_oke_node_pool,
#         oci_identity_domains_app.idcs_app
#     ]
# }

# resource "null_resource" "create_langfuse_lb" {
#     triggers = {
#         file = file("./scripts/langfuse.Ingress.yaml")
#     }
#   # TODO 
#   # create the public load balancer via k8s Service, 
#   # fetch the IP, 
#   # create the certificate for the LB based on IP, 
#   # update the helm chart value for LANGFUSE_HOSTNAME
#   # update the IDCS app with the URL for login redirect
#   connection {
#     type        = "ssh"
#     user        = "opc"
#     private_key = tls_private_key.bastion_session_public_private_key_pair.private_key_openssh
#     host        = oci_core_instance.langfuse_builder.public_ip
#   }

#   provisioner "file" {
#     source      = "./scripts/langfuse.Ingress.yaml"
#     destination = "/home/opc/langfuse.Ingress.yaml"
#   }


#   provisioner "remote-exec" {
#     when = create
#     # wrap the inline script into a template script file so the file content can be used as a trigger 
#     # and this runs each time the script changes
#     inline = [<<EOF
#         # deploy nginx ingress controller
#         kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.1/deploy/static/provider/cloud/deploy.yaml
#         # deploy our ingress
#         kubectl get namespace langfuse || kubectl create namespace langfuse
#         sed -i 's|$DEPLOY_ID|${local.deploy_id}|gm' langfuse.Ingress.yaml
#         kubectl apply -f langfuse.Ingress.yaml --namespace langfuse
#     EOF
#     ]
#   }

#   depends_on = [
#     null_resource.builder_run,
#     oci_containerengine_node_pool.oci_oke_node_pool,
#   ]
# }

# TODO
# Fix this look up - we need to be able to look up the specific load balancer. Here we only have 1 if we start fresh but that may not be the
# case everywhere at all. We need to find a way to provide a name to the load balancer, or provide tags and filter by tags.
# data "oci_load_balancer_load_balancers" "load_balancers" {
#     #Required
#     compartment_id = var.cluster_compartment_id

#     #Optional
#     detail = "full"
#     # display_name = "langfuse-web-${local.deploy_id}"

#     depends_on = [ null_resource.create_langfuse_lb ]
# }

# locals {
#     langfuse_hostname = data.oci_load_balancer_load_balancers.load_balancers.load_balancers[0].ip_addresses[0]
# }

# output "lbs" {
#     value = data.oci_load_balancer_load_balancers.load_balancers
# }


## Terminate the builder instance when done
# resource "null_resource" "terminate_builder" {
#   connection {
#     type        = "ssh"
#     user        = "opc"
#     private_key = tls_private_key.bastion_session_public_private_key_pair.private_key_openssh
#     host        = oci_core_instance.langfuse_builder.public_ip
#   }

#   provisioner "remote-exec" {
#     when = create
#     # wrap the inline script into a template script file so the file content can be used as a trigger 
#     # and this runs each time the script changes
#     inline = [
#       <<EOF
#         EOF
#     ]
# }


#     depends_on = [
#         # all scripts than need to run successfully
#     ]
# }


output "builder" {
  value     = module.builder_instance.details
  sensitive = true
}