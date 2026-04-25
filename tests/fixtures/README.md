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

`fixture-prewarm` uses the ordered live suite to create the shared warm footprint ahead of time:

- `network`
- the first `basic` profile in planned live order
- the first `enhanced` profile in planned live order

After prewarm, the runner intentionally keeps warm `basic` and `enhanced` fixtures across unrelated live scenarios so later profile groups can reuse them instead of rebuilding from cold state.

For live suite planning, the `enhanced` fixture is treated as two layers:

- cluster settings, currently driven by the cluster endpoint exposure
- node-pool settings, currently driven by pool size and custom cloud-init

That lets the runner keep an enhanced cluster warm while Terraform cycles only the node pool when a scenario switches between compatible enhanced profiles.
