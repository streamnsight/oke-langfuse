variable "compartment_id" {
  type = string
}

variable "compute_shape" {
  type = string
}

variable "display_name" {
  type    = string
  default = "builder"
}

variable "availability_domain" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "metadata" {

}

variable "ssh_authorized_keys" {
  type = string
}

variable "ocpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 24
}

variable "image_id" {
  type = string
}

variable "boot_volume_gb" {
  type    = number
  default = 100
}

variable "policies" {
  type = list(string)
  default = [
    "manage instance-family",
  ]
}