## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
}

variable "ocir_region" {
  type        = string
  description = "OCIR Container Registry Region"
  default     = "us-ashburn-1"
}
