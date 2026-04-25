# Shared Network Fixture

This directory contains the reusable VCN fixture used by the cluster fixture stacks.

Current behavior:

- creates one shared VCN
- creates API, load balancer, and 3 node pool subnets
- creates NAT, Internet, and Service gateways
- creates route tables and OKE-oriented security lists
- exposes subnet IDs through `terraform output -json`

The fixture lifecycle interface is already wired through:

```bash
make fixture ACTION=status TARGET=network
make fixture ACTION=up TARGET=network
make fixture ACTION=down TARGET=network
```

Real values should be injected through `tests/.env` plus an optional local `terraform.tfvars`.
