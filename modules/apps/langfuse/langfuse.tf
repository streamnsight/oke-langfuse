resource "local_file" "sock5_privatekey" {
  content         = var.bastion_session_private_key_content
  filename        = "${path.module}/bastionKey.pem"
  file_permission = "0400"
}

resource "null_resource" "install" {

  # build langfuse image and push to registry
  provisioner "local-exec" {
    command = "${path.module}/scripts/build_langfuse_image.sh"
    # Optional arguments:
    when       = create
    on_failure = fail # or "continue"
    environment = {
      MODULE_PATH            = "${path.module}"
      COMPARTMENT_ID         = var.compartment_id
      REGION                 = var.region
      TENANCY_NAMESPACE      = data.oci_objectstorage_namespace.ns.namespace
      LANGFUSE_IMAGE_VERSION = "v3.122.1"
      LANGFUSE_K8S_NAMESPACE = "langfuse"
    }
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_langfuse_secrets.sh"
    # Optional arguments:
    when       = create
    on_failure = fail # or "continue"
    environment = {
      CLUSTER_ID                  = var.cluster_id
      BASTION_SESSION_ID          = var.bastion_session_id
      MODULE_PATH                 = "${path.module}"
      IDCS_CLIENT_ID              = var.idcs_client_id
      IDCS_CLIENT_SECRET          = var.idcs_client_secret
      IDCS_APP_ID                 = var.idcs_app_id
      PASSWORD_ENCRYPTION_KEY     = random_string.password_encryption_key.result
      PASSWORD_ENCRYPTION_SALT    = random_string.password_encryption_salt.result
      NEXTAUTH_SECRET             = random_string.nextauth_secret.result
      CLICKHOUSE_PASSWORD         = random_string.clickhouse_password.result
      OBJECTSTORAGE_S3_ACCESS_KEY = var.s3_client_id
      OBJECTSTORAGE_S3_SECRET_KEY = var.s3_client_secret
      PSQL_CERTIFICATE            = var.psql_cert
      PSQL_PASSWORD               = var.psql_password
      LANGFUSE_K8S_NAMESPACE      = "langfuse"
    }
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/install_langfuse_helm_chart.sh"
    # Optional arguments:
    when       = create
    on_failure = fail # or "continue"
    environment = {
      CLUSTER_ID               = var.cluster_id
      MODULE_PATH              = "${path.module}"
      BASTION_SESSION_ID       = var.bastion_session_id
      COMPARTMENT_ID           = var.compartment_id
      REGION                   = var.region
      TENANCY_NAMESPACE        = data.oci_objectstorage_namespace.ns.namespace
      LANGFUSE_DEPLOYMENT_NAME = "langfuse"
      LANGFUSE_K8S_NAMESPACE   = "langfuse"
      REDIS_HOSTNAME           = var.redis_hostname
    }
  }
  depends_on = [
    local_file.sock5_privatekey
  ]
}