## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "langfuse_helm_chart_version" {
  type        = string
  description = "Langfuse Helm chart version: chart 1.x selects the v3 builder; chart 2.x selects the v4 builder."

  validation {
    condition     = can(regex("^[12]\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$", var.langfuse_helm_chart_version))
    error_message = "langfuse_helm_chart_version must be a chart 1.x or 2.x version; newer chart majors require an explicit build-script mapping."
  }
}

locals {
  image_build_script = startswith(var.langfuse_helm_chart_version, "1.") ? "build_langfuse_image.sh" : "build_langfuse_image_v4.sh"
}
