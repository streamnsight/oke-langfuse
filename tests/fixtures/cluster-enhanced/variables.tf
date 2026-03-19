variable "region" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "cluster_compartment_id" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "tests-enhanced-cluster"
}

variable "kubernetes_version" {
  type    = string
  default = "v1.34.1"
}

variable "pods_cidr" {
  type    = string
  default = "10.110.0.0/16"
}

variable "services_cidr" {
  type    = string
  default = "10.111.0.0/16"
}

variable "create_bastion" {
  type    = bool
  default = true
}

variable "use_custom_cloud_init" {
  type    = bool
  default = true
}

variable "node_pool_size" {
  type    = number
  default = 2
}

variable "node_shape" {
  type    = string
  default = "VM.Standard.E5.Flex"
}

variable "node_shape_ocpus" {
  type    = number
  default = 4
}

variable "node_shape_memory_gb" {
  type    = number
  default = 16
}

variable "node_boot_volume_size_gb" {
  type    = number
  default = 150
}

variable "fixture_node_image_id" {
  type        = string
  description = "Base compute image OCID used to derive the OKE-optimized node image."
}

variable "fixture_availability_domain" {
  type    = string
  default = null
}

variable "ssh_public_key" {
  type    = string
  default = null
}

variable "defined_tags" {
  type    = map(string)
  default = {}
}
