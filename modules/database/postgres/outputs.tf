
output "details" {
  value = {
    endpoint = data.oci_psql_db_system_connection_detail.psql_connection_detail.primary_db_endpoint[0]
    cert     = data.oci_psql_db_system_connection_detail.psql_connection_detail.ca_certificate
    password = random_string.postgres_password.result
  }
}

