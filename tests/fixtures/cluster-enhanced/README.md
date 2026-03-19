# Enhanced Cluster Fixture

This directory is reserved for the reusable private-endpoint `ENHANCED_CLUSTER` fixture that attaches to the shared network fixture.

Expected purpose:

- provision an enhanced OKE cluster on the shared VCN
- provision one node pool that can be scaled between 2 and 3 nodes
- optionally provision a bastion used by `obc`
- expose cluster and bastion IDs through `terraform output -json`

The lifecycle interface is already wired through:

```bash
make fixture ACTION=status TARGET=enhanced
make fixture ACTION=up TARGET=enhanced
make fixture ACTION=scale TARGET=enhanced SIZE=2
make fixture ACTION=scale TARGET=enhanced SIZE=3
make fixture ACTION=down TARGET=enhanced
```
