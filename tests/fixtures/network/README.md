# Shared Network Fixture

This directory is reserved for the reusable VCN fixture used by the cluster fixture stacks.

Expected purpose:

- create the shared VCN
- create the API, load balancer, and node pool subnets
- expose subnet IDs through `terraform output -json`

The fixture lifecycle interface is already wired through:

```bash
make fixture ACTION=status TARGET=network
make fixture ACTION=up TARGET=network
make fixture ACTION=down TARGET=network
```

Populate this workspace with Terraform files as the network fixture implementation is added.
