# node-image-selector

This module selects an OKE-ready worker image from declarative inputs:

- `operating_system`
- `operating_system_version`
- `shape`
- `kubernetes_version`

It queries OKE node pool sources directly, filters them to the requested OS,
OS version, shape family, and Kubernetes version, then resolves the matching
image OCIDs and picks the newest matching OKE image by `time_created`.

A separate platform image entry is not required. The `base_image_id` and
`base_image_display_name` diagnostic outputs are null when OKE does not list
the corresponding platform image (as can happen for Oracle Linux 9).

Run the selector regression tests with `terraform init -backend=false` followed
by `terraform test` from this module directory. These tests mock OCI responses
and do not create cloud resources.

Set `image_id_override` to bypass lookup and force a specific image OCID.
