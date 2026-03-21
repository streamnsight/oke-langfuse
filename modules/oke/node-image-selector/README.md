# node-image-selector

This module selects an OKE-ready worker image from declarative inputs:

- `operating_system`
- `operating_system_version`
- `shape`
- `kubernetes_version`

It first looks up a compatible platform image with `oci_core_images`, then maps
that base image to the matching OKE-optimized image for the requested
Kubernetes version by composing the existing `recommended-compute-image`
module.

Set `image_id_override` to bypass lookup and force a specific image OCID.
