# OKE Cloud Init Script Module

This module provides and manages cloud-init scripts for Oracle Kubernetes Engine (OKE) node VMs. It enables automated initialization and configuration of worker nodes during provisioning.

The registry helper installs `python36-oci-cli` on Oracle Linux 8 and
`python39-oci-cli` on Oracle Linux 9 when the OCI CLI is missing. Installation
errors stop the helper without changing the preceding OKE registration script.

Run `python3 tests/cloud_init/test_cli_bootstrap.py` from the repository root
to test package selection and installation failures with isolated paths and
mocked commands. These checks do not replace a private-image pull test on a
joined OKE node.
