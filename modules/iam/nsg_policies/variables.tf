variable "nsg_name" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "permissions" {
  type = list(string)
}

variable "use_nsg" {
  type    = bool
  default = true
}