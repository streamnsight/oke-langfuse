variable "compartment_id" {
  type = string
}

variable "db_version" {
  type    = string
  default = "16"
}

variable "memory_gb" {
  type    = string
  default = "64"
}

variable "ocpus" {
  type    = string
  default = 2
}

variable "postgresql_shape" {
  type    = string
  default = ""
}

variable "subnet_id" {
  type = string
}

variable "availability_domains" {
  type = list(any)
}