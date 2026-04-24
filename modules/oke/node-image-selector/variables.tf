## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "compartment_id" {
  type        = string
  description = "Compartment OCID used to list candidate platform images."
}

variable "kubernetes_version" {
  type        = string
  description = "Requested Kubernetes version for the OKE node pool."
}

variable "operating_system" {
  type        = string
  description = "Platform image operating system, for example Oracle Linux."
}

variable "operating_system_version" {
  type        = string
  description = "Platform image operating system version, for example 8."
}

variable "shape" {
  type        = string
  description = "Node shape used to filter compatible base images."
}

variable "image_id_override" {
  type        = string
  description = "Optional explicit image OCID override. When set, selector lookup is bypassed."
  default     = null
}
