# Copyright (c) 2021, 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

output "manifest_yaml" {
  value = local.manifest_yaml
}

output "default_api_key" {
  value = random_string.oci_genai_gateway_default_api_key.result
}