# Basic Cluster Fixture

This directory contains the reusable private-endpoint `BASIC_CLUSTER` fixture that attaches to the shared network fixture.

Current behavior:

- reads the shared network outputs from `../network/terraform.tfstate`
- provisions a private-endpoint `BASIC_CLUSTER`
- optionally provisions a bastion used by `obc`
- exposes cluster and bastion IDs through `terraform output -json`

The lifecycle interface is already wired through:

```bash
make fixture ACTION=status TARGET=basic
make fixture ACTION=up TARGET=basic
make fixture ACTION=down TARGET=basic
```
