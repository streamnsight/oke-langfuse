# node-image-selector

This module selects an OKE-ready worker image from declarative inputs:

- `operating_system`
- `operating_system_version`
- `shape`
- `kubernetes_version`

It queries OKE node pool sources directly, filters them to the requested OS,
OS version, shape family, and Kubernetes version, then resolves the matching
image OCIDs and picks the newest matching OKE image by `time_created`.

Set `image_id_override` to bypass lookup and force a specific image OCID.
