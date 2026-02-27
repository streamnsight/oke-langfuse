## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "details" {
  value = {
    endpoint = data.oci_psql_db_system_connection_detail.psql_connection_detail.primary_db_endpoint[0]
    cert     = data.oci_psql_db_system_connection_detail.psql_connection_detail.ca_certificate
    password = random_string.postgres_password.result
    ocid     = oci_psql_db_system.langfuse_postgres.id
  }
}

