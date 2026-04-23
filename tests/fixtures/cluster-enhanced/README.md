# Enhanced Cluster Fixture

This directory contains the reusable `ENHANCED_CLUSTER` fixture that attaches to the shared network fixture.

Current behavior:

- reads the shared network outputs from `../network/terraform.tfstate`
- provisions an `ENHANCED_CLUSTER` that can be switched between private and public endpoint modes
- provisions one node pool that can be scaled between 2 and 3 nodes
- resolves an OKE-ready node image from Kubernetes version, OS, OS version, and shape by default
- can switch between default OKE node metadata and the stack cloud-init helper
- optionally provisions a bastion used by `obc`
- keeps `fixture_node_image_id` as an escape hatch when a manual image override is needed
- exposes cluster, bastion, and image-selector details through `terraform output -json`
- is planned by the live harness as layered cluster plus node-pool state so compatible scenarios can reuse the cluster and pay only for node-pool cycling when size or cloud-init changes

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
