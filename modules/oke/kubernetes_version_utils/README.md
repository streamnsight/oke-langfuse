# kubernetes_version_utils

This module provides information about the kubernetes versions semantic version chunks for the closest and latest supported versions, given a kubernetes version.

It returns:

- `available`: A list of avsailable version for the cluster.
- `is_available`: A boolean that defines if the version provided is available.
- `latest`: The latest version available.
- `closest`: The closest match to the provided version (closest match within the same major version if it is available, the latest version if the version provided is not supported yet, and the oldest supported version if the version provided is no longer supported). If not version was provided, returns the latest version.
- `selected`: The version selected, either latest version if no version was provided, or the closest match.
- `semver`: The list of the semantic version chunks of the selected version.
- `major`: The major version number of the semver
- `minor`: The minor version number of the semver
- `major_minor`: The major.minor version string of the semver
