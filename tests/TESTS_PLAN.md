# Tests Plan

## Summary

This repository keeps all test assets under `./tests` so test orchestration stays separate from stack-owned runtime and provisioning scripts under `./scripts`.

Target layout:

- `tests/scripts/` for runners, fixture lifecycle scripts, debug helpers, and shared shell or `jq` utilities
- `tests/scenarios/` for fast scenario-based validation inputs
- `tests/fixtures/` for reusable VCN and cluster fixture wrappers
- `tests/artifacts/` for generated logs and result snapshots
- `tests/TESTS_PLAN.md` as the master plan and scenario inventory

The only expected root-level test entrypoint is the thin `Makefile`, which forwards to `tests/scripts/run.sh`.

## Structure Changes

### 1. Test tooling lives under `tests/scripts/`

- Moved the scenario validation runner out of root `scripts/`
- Kept root `scripts/` reserved for stack-owned provisioning and build helpers
- Standardized on `tests/scripts/run.sh` as the shared entrypoint

Planned workspace shape:

- `tests/TESTS_PLAN.md`
- `tests/README.md`
- `tests/scripts/run.sh`
- `tests/scripts/validate_scenarios.sh`
- `tests/scripts/lib/*.sh`
- `tests/scripts/lib/*.jq`
- `tests/scenarios/...`
- `tests/fixtures/network/...`
- `tests/fixtures/cluster-basic/...`
- `tests/fixtures/cluster-enhanced/...`
- `tests/artifacts/`

### 2. One parameterized interface

Preferred interface:

- `tests/scripts/run.sh test SCENARIO=<name>`
- `tests/scripts/run.sh test SUITE=<all|fast> [SCENARIO=<name>]`
- `tests/scripts/run.sh fixture ACTION=<up|down|refresh|status|scale> TARGET=<network|basic|enhanced> [SIZE=2|3]`
- `tests/scripts/run.sh debug TARGET=<network|basic|enhanced> [SCENARIO=<name>]`

Thin root shortcuts:

- `make test SCENARIO=...`
- `make test SUITE=fast`
- `make fixture ACTION=... TARGET=...`
- `make debug TARGET=...`

### 3. Self-contained test workspace

Everything test-specific should live under `./tests`:

- shell helpers
- `jq` helpers
- scenario definitions
- fixture wrappers
- OCI DevOps inspection helpers
- `obc` and `kubectl` debug tooling
- generated test artifacts and summaries
- test documentation

The stack itself only exposes non-sensitive metadata when `test_mode = true`.
Real deployment values should be injected from `tests/.env` or environment variables rather than committed tfvars.

## Implementation Changes

### 1. Fast scenario runner

- Keep scenario-based validation and avoid `terraform test`
- Preserve `tests/scenarios/...` as the source of fast validation inputs
- Support `SCENARIO=<name>` for single-scenario execution
- Support `SUITE=fast` for PR-safe validation that does not require fixtures or live OCI infrastructure
- Support full-suite execution when `SCENARIO` is omitted
- Capture per-run logs under `tests/artifacts/test/...`
- Clean up successful per-run artifacts by default to avoid unbounded local log growth, with an opt-out env var for debugging
- Aggregate scenario failures across a suite run so a single execution shows the full set of broken tests that need fixing

### 2. Shared fixtures under `tests/fixtures/`

Fixture targets:

- `network`
- `basic`
- `enhanced`

Lifecycle rule:

- the shared network cannot be destroyed while `basic` or `enhanced` fixture state still exists

This repo now includes the fixture workspace layout, example variable files, and dependency-aware tooling. The actual fixture Terraform definitions can now be filled in incrementally without changing the interface.

### 3. JSON and `jq`-based inspection

The harness uses:

- `terraform output -json`
- saved begin and end snapshots
- reusable `jq` filters for:
  - cluster IDs
  - bastion IDs
  - subnet IDs
  - DevOps project and environment IDs

### 4. OCI DevOps and cluster debugging

The debug tooling under `tests/scripts/` can:

- collect OCI DevOps deployment summaries
- inspect per-stage state through OCI CLI
- register clusters through `obc`
- switch `kubectl` context
- collect namespace, pod, event, and log diagnostics

All debug artifacts are written under `tests/artifacts/debug/...`.

## Scenario Inventory

Fast validation scenarios to maintain first:

- `networking/valid_existing_vcn`
- `networking/invalid_existing_vcn_missing_subnets`
- `networking/invalid_ocid_format`
- `networking/invalid_cross_compartment`
- `existing_cluster/invalid_missing_cluster_ocid`
- `existing_cluster/invalid_empty_cluster_ocid`

Next scenarios to add incrementally:

- missing `cluster_ocid` when `use_existing_cluster = true`
- existing basic cluster rejected
- existing enhanced cluster with only two nodes rejected
- existing enhanced cluster with default OKE cloud-init rejected by the optional preflight
- existing enhanced cluster with three nodes accepted
- cross-compartment rejection

Fixture-backed cloud-init coverage:

- enhanced fixture with `USE_CUSTOM_CLOUD_INIT=false` should reproduce the unsuitable existing-cluster path
- enhanced fixture with `USE_CUSTOM_CLOUD_INIT=true` and `SIZE=3` should satisfy the cloud-init preflight


## Assumptions

- `./tests` is the dedicated home for the test harness
- root `scripts/` should not contain test orchestration
- the root `Makefile` is only a convenience passthrough
- shared fixtures remain dependency-aware because the VCN is reused
- any stack changes for testing must remain non-sensitive
- real tenancy, compartment, vault, and credential values should live in ignored `tests/.env` files or injected environment variables
