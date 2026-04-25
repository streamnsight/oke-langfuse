terraform {
  required_version = ">= 1.4"

  required_providers {
    oci = {
      source = "hashicorp/oci"
    }
    random = {
      source = "hashicorp/random"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region       = var.region
}
