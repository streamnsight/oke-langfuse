variable "compartment_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "bastion_client_cidr_block_allow_list" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "bastion_name" {
  type    = string
  default = "bastion"
}