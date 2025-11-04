# resource "local_file" "sock5_privatekey" {
#   content         = var.bastion_session_private_key_content
#   filename        = "${path.module}/bastionKey.pem"
#   file_permission = "0400"
# }

# resource "null_resource" "install" {

#   triggers = {
#     bastion_session_id = var.bastion_session_id
#   }

#   # build and deploy OCI GenAI Gateway
#   provisioner "local-exec" {
#     command = "${path.module}/scripts/deploy_oci_genai_gateway.sh"
#     # Optional arguments:
#     when       = create
#     on_failure = fail # or "continue"
#     environment = {
#       REGION                 = var.region
#       CLUSTER_ID             = var.cluster_id
#       AUTH_TYPE              = "INSTANCE_PRINCIPAL"
#       MODULE_PATH            = "${path.module}"
#       BASTION_SESSION_ID     = var.bastion_session_id
#       COMPARTMENT_ID         = var.compartment_id
#       TENANCY_NAMESPACE      = data.oci_objectstorage_namespace.ns.namespace
#       OCI_GENAI_GATEWAY_TAG  = var.oci_genai_gateway_tag
#       LANGFUSE_K8S_NAMESPACE = "langfuse"
#     }
#   }
#   depends_on = [
#     local_file.sock5_privatekey
#   ]
# }