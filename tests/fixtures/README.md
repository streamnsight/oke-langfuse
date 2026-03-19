# Fixtures

Fixture workspaces are kept under this directory so their Terraform state, examples, and helper files remain part of the self-contained test workspace.

Targets:

- `network`
- `cluster-basic`
- `cluster-enhanced`

The lifecycle tooling in `tests/scripts/run.sh` already understands the short target names:

- `network`
- `basic`
- `enhanced`

The network fixture is shared by both cluster fixtures, so the tooling prevents destroying the network while either cluster fixture still has Terraform state.
