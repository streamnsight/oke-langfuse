## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}


data "external" "langfuse_version" {
  program = ["${path.module}/scripts/get_langfuse_version.sh"]
  query = {
    langfuse_helm_chart_version = var.langfuse_helm_chart_version
  }
}
