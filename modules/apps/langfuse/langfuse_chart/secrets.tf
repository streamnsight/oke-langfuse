
resource "random_string" "langfuse_password_encryption_key" {
  length      = 64
  special     = false
  min_lower   = 2
  min_upper   = 2
  min_numeric = 4
}

resource "random_string" "langfuse_password_encryption_salt" {
  length      = 24
  special     = false
  min_lower   = 2
  min_upper   = 2
  min_numeric = 4
}

resource "random_string" "langfuse_next_auth_secret" {
  length      = 48
  special     = false
  min_lower   = 2
  min_upper   = 2
  min_numeric = 4
}

resource "random_string" "langfuse_clickhouse_password" {
  length      = 24
  special     = false
  min_lower   = 2
  min_upper   = 2
  min_numeric = 4
}


resource "local_file" "langfuse_postgres_cert" {
  content  = var.psql_cert
  filename = "${path.module}/CaCertificate-langfuse.pub"
}



# creates secrets for langfuse. We don't want these coded into a manifest stored in artifacts, 
# or passing secrets as ENV variables to a build step
# so this ensures secrets are created without leaving the 
resource "null_resource" "create_langfuse_secrets" {
  triggers = {
    instance_id         = var.builder_details.instance_id
    script              = file("${path.module}/scripts/create_langfuse_secrets.sh")
    encryption_key      = random_string.langfuse_password_encryption_key.result
    salt                = random_string.langfuse_password_encryption_salt.result
    nextauth_secret     = random_string.langfuse_next_auth_secret.result
    clickhouse_password = random_string.langfuse_clickhouse_password.result
    redis_password      = var.redis_password
    postgres_password   = var.psql_password
    app_id              = var.idcs_app_id
  }
  connection {
    type        = "ssh"
    user        = "opc"
    private_key = var.builder_details.private_key
    host        = var.builder_details.ip_address
  }

  provisioner "file" {
    source      = "${path.module}/CaCertificate-langfuse.pub"
    destination = "/home/opc/CaCertificate-langfuse.pub"
  }

  provisioner "remote-exec" {
    when = create
    # wrap the inline script into a template script file so the file content can be used as a trigger 
    # and this runs each time the script changes
    inline = [
      <<EOF
            ${templatefile("${path.module}/scripts/create_langfuse_secrets.sh", {
      encryption_key      = random_string.langfuse_password_encryption_key.result
      salt                = random_string.langfuse_password_encryption_salt.result
      nextauth_secret     = random_string.langfuse_next_auth_secret.result
      clickhouse_password = random_string.langfuse_clickhouse_password.result
      redis_password      = var.redis_password
      client_id           = var.idcs_client_id
      client_secret       = var.idcs_client_secret
      issuer              = var.idcs_domain_url
      s3_access_key       = var.s3_client_id
      s3_secret_key       = var.s3_client_secret
      postgres_password   = var.psql_password
      database_url        = "postgresql://langfuse:${var.psql_password}@${var.psql_endpoint.fqdn}:${var.psql_endpoint.port}/postgres?sslmode=verify-full&sslrootcert=/secrets/db-keystore/CaCertificate-langfuse.pub"
})}
    EOF
]
}


# depends_on = [
#   null_resource.builder_run,
#   oci_containerengine_node_pool.oci_oke_node_pool,
#   oci_identity_domains_app.idcs_app
# ]
}
