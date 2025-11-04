variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
}

variable "ocir_region" {
  type        = string
  description = "OCIR Container Registry Region"
  default     = "us-ashburn-1"
}