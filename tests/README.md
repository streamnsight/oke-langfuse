# Test Workspace

This repository keeps test tooling under `./tests` so it stays separate from stack-owned scripts under `./scripts`.

## Layout

- `tests/scripts/` contains the test runner and helper libraries
- `tests/scenarios/` contains fast scenario-based validation inputs
- `tests/fixtures/` contains reusable fixture workspaces and examples
- `tests/artifacts/` stores generated test outputs and debug snapshots

## Environment

Real tenancy, compartment, vault, and credential-related values should not be committed to the repo.

Use:

```bash
cp tests/.env.example tests/.env
```

Then fill in real values in `tests/.env`. The test runner automatically loads:

- `tests/.env`
- `tests/.env.local`

The recommended pattern is to store Terraform inputs as `TF_VAR_*` exports so both fixture workspaces and stack-level Terraform commands pick them up automatically.

## Commands

From the repo root:

```bash
make test
make test SUITE=fast
make test SUITE=live
make test SUITE=live LIVE_FIXTURE_FINAL_CLEANUP=success
make test SCENARIO=existing_cluster/invalid_empty_cluster_ocid
make test SUITE=all SCENARIO=networking/valid_existing_vcn

make fixture ACTION=status TARGET=network
make fixture ACTION=up TARGET=enhanced
make fixture ACTION=scale TARGET=enhanced SIZE=3
make fixture ACTION=refresh TARGET=enhanced USE_CUSTOM_CLOUD_INIT=false
make fixture-down-all

make debug TARGET=enhanced
```

Direct runner usage:

```bash
./tests/scripts/run.sh test
./tests/scripts/run.sh test SUITE=fast
./tests/scripts/run.sh test SUITE=live
./tests/scripts/run.sh test SUITE=live LIVE_FIXTURE_FINAL_CLEANUP=success
./tests/scripts/run.sh test SCENARIO=existing_cluster/invalid_empty_cluster_ocid
./tests/scripts/run.sh test SUITE=all SCENARIO=networking/invalid_ocid_format
./tests/scripts/run.sh fixture ACTION=status TARGET=basic
./tests/scripts/run.sh fixture ACTION=refresh TARGET=enhanced USE_CUSTOM_CLOUD_INIT=false
./tests/scripts/run.sh fixture-down-all
./tests/scripts/run.sh debug TARGET=enhanced
```

## Notes

- `test` defaults to `SUITE=fast`, runs blocking root preflight checks first, and then runs the selected suite.
- Blocking preflight currently includes `terraform init -backend=false -input=false` and `terraform validate`.
- The fast suite intentionally uses scenario validation and not `terraform test`.
- `test` runs aggregate scenario failures and report a final summary instead of stopping on the first failing case.
- The fixture directories are now isolated under `tests/fixtures/`.
- The enhanced fixture accepts `USE_CUSTOM_CLOUD_INIT=true|false` so we can test both the default OKE bootstrap and the stack's custom OCIR bootstrap.
- `make fixture-down-all` is the explicit manual cleanup step for live runs. It destroys `enhanced`, then `basic`, then `network`.
- When `test_mode = true`, the stack exposes extra non-sensitive metadata through `terraform output -json` for local inspection tooling.
- Successful `test` and `fixture` runs clean up their timestamped artifact directories by default. Set `TESTS_KEEP_SUCCESS_ARTIFACTS=true` if you want to retain successful logs locally.
- Failed scenarios now print expected-vs-actual diagnostics when available and point to the saved Terraform logs under `tests/artifacts/` so you can jump straight to the relevant run output.
- `SUITE=fast` is the CI-safe subset used on pull requests and includes only scenarios explicitly tagged for `fast` in `scenario.json` or legacy `suites.txt` metadata.
- `SUITE=live` is the local OCI-backed subset for fixture-based existing-cluster compatibility checks and self-bootstraps the required `network`, `basic`, and `enhanced` fixture profiles from empty local state.
- Live scenarios declare explicit `infra.profile` and `infra.bootstrap` metadata in `scenario.json`. The live suite groups scenarios by profile, orders the groups to minimize cluster churn, reconciles `enhanced` cluster and node-pool settings in place, and only tears down fixture targets that are no longer needed by the next group.
- By default the live suite leaves the last prepared fixtures warm after a successful run. Set `LIVE_FIXTURE_FINAL_CLEANUP=success` to destroy all fixture targets touched by the suite in dependency order after success.
- `SUITE=live` also includes multi-step managed-cluster drift scenarios that use the shared network fixture plus OCI CLI to perform an out-of-band cluster upgrade.
- The full-stack live deployment scenario now deploys once, runs multiple post-deploy validators, destroys the stack on success, and keeps it on failure for debugging.
- `tests/.env` and `tests/.env.local` are ignored by git and are the right place for real local test values.
- The harness defaults `OBC_ROOT_DIR` to `tests/.obc` so `obc registry oke add`, `kubectl`, and later `obc kube-exec` subprocesses share the same persistent local state. Export `OBC_ROOT_DIR` yourself if you want a different location.
- `make debug TARGET=...` resolves DevOps runtime IDs from `terraform output -json` first and only uses `PROJECT_ID`, `PIPELINE_ID`, or `DEPLOYMENT_ID` as optional manual overrides.
