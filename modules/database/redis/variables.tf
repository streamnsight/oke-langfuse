variable "compartment_id" {
  type = string
}

variable "display_name" {
  type = string
}
variable "subnet_id" {
  type = string
}

variable "node_count" {
  type    = string
  default = "1"
}

variable "node_memory" {
  type    = string
  default = "16"
}