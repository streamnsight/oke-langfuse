# Enhanced Cluster Fixture

This directory contains the reusable `ENHANCED_CLUSTER` fixture that attaches to the shared network fixture.

Current behavior:

- reads the shared network outputs from `../network/terraform.tfstate`
- provisions an `ENHANCED_CLUSTER` that can be switched between private and public endpoint modes
- provisions one node pool that can be scaled between 2 and 3 nodes
- can switch between default OKE node metadata and the stack cloud-init helper
- optionally provisions a bastion used by `obc`
- exposes cluster and bastion IDs through `terraform output -json`

The lifecycle interface is already wired through:

```bash
make fixture ACTION=status TARGET=enhanced
make fixture ACTION=up TARGET=enhanced
make fixture ACTION=scale TARGET=enhanced SIZE=2
make fixture ACTION=scale TARGET=enhanced SIZE=3
make fixture ACTION=refresh TARGET=enhanced USE_CUSTOM_CLOUD_INIT=false
make fixture ACTION=refresh TARGET=enhanced IS_PUBLIC_ENDPOINT=true SIZE=3
make fixture ACTION=down TARGET=enhanced
```
