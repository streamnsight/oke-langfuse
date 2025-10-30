# Copyright (c) 2021, 2023, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

variable "image_id" {
  type        = string
  description = "OCI of the compute image"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
}