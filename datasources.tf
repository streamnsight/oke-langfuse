## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

data "oci_containerengine_cluster_option" "cluster_options" {
  cluster_option_id = "all"
}

data "oci_containerengine_node_pool_option" "oci_oke_node_pool_option" {
  node_pool_option_id = "all"
}

# Gets home and current regions
data "oci_identity_tenancy" "tenant_details" {
  tenancy_id = var.tenancy_ocid
  provider   = oci.current_region
}

data "oci_identity_regions" "home_region" {
  filter {
    name   = "key"
    values = [data.oci_identity_tenancy.tenant_details.home_region_key]
  }
  provider = oci.current_region
}

data "oci_core_services" "all_oci_services" {
  count = 1
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

# output "ADs" {
#   value = data.oci_identity_availability_domains.ADs
# }

data "oci_identity_compartments" "test_compartments" {
  #Required
  compartment_id = var.cluster_compartment_id

  #Optional
  access_level = "ACCESSIBLE"
  # compartment_id_in_subtree = var.compartment_compartment_id_in_subtree

  lifecycle {
    postcondition {
      # This condition checks the instance state after creation
      condition     = var.cluster_compartment_id == var.devops_compartment_id && var.cluster_compartment_id == var.vcn_compartment_id && var.cluster_compartment_id == var.secrets_store_vault_compartment_id
      error_message = "Cross compartment deployment is not suported at this time. VCN, Vautl, Cluster all need to be in the same compartment"
    }
  }
}


data "oci_container_instances_container_instance_shape" "container_instance_shapes" {
  compartment_id = var.devops_compartment_id
}


# Deploy ID to uniquely identify this cluster and associated resources.
resource "random_string" "deploy_id" {
  length      = 4
  special     = false
  min_numeric = 4
}

locals {
  deploy_id = random_string.deploy_id.result
  ci_shapes = data.oci_container_instances_container_instance_shape.container_instance_shapes.items[*].name
  ci_shape_selected = (contains(local.ci_shapes, "CI.Standard.E3.Flex") ?
    "CI.Standard.E3.Flex" : contains(local.ci_shapes, "CI.Standard.E4.Flex") ?
    "CI.Standard.E4.Flex" : contains(local.ci_shapes, "CI.Standard.E5.Flex") ?
    "CI.Standard.E5.Flex" : "CI.Standard.x86.Generic"
  )

}

data "oci_identity_domain" "identity_domain" {
  count     = var.create_idcs_app ? 1 : 0
  domain_id = var.identity_domain_id
}

data "oci_identity_domains_settings" "identity_settings" {
  #Required
  idcs_endpoint = var.create_idcs_app ? data.oci_identity_domain.identity_domain[0].url : var.idcs_domain_url

  lifecycle {
    postcondition {
      # This condition checks the instance state after creation
      condition     = self.settings[0].signing_cert_public_access == true
      error_message = "Signing certificate needs to have public access."
    }
  }
}
