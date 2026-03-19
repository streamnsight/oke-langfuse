# Basic Cluster Fixture

This directory is reserved for the reusable private-endpoint `BASIC_CLUSTER` fixture that attaches to the shared network fixture.

Expected purpose:

- provision a basic OKE cluster on the shared VCN
- optionally provision a bastion used by `obc`
- expose cluster and bastion IDs through `terraform output -json`

The lifecycle interface is already wired through:

```bash
make fixture ACTION=status TARGET=basic
make fixture ACTION=up TARGET=basic
make fixture ACTION=down TARGET=basic
```
