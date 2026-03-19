# Enhanced Cluster Fixture

This directory contains the reusable private-endpoint `ENHANCED_CLUSTER` fixture that attaches to the shared network fixture.

Current behavior:

- reads the shared network outputs from `../network/terraform.tfstate`
- provisions a private-endpoint `ENHANCED_CLUSTER`
- provisions one node pool that can be scaled between 2 and 3 nodes
- uses the stack cloud-init helper for node metadata
- optionally provisions a bastion used by `obc`
- exposes cluster and bastion IDs through `terraform output -json`

The lifecycle interface is already wired through:

```bash
make fixture ACTION=status TARGET=enhanced
make fixture ACTION=up TARGET=enhanced
make fixture ACTION=scale TARGET=enhanced SIZE=2
make fixture ACTION=scale TARGET=enhanced SIZE=3
make fixture ACTION=down TARGET=enhanced
```
