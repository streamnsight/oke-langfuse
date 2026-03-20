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
make test SCENARIO=existing_cluster/invalid_empty_cluster_ocid
make test SUITE=all SCENARIO=networking/valid_existing_vcn

make fixture ACTION=status TARGET=network
make fixture ACTION=up TARGET=enhanced
make fixture ACTION=scale TARGET=enhanced SIZE=3
make fixture ACTION=refresh TARGET=enhanced USE_CUSTOM_CLOUD_INIT=false

make debug TARGET=enhanced
```

Direct runner usage:

```bash
./tests/scripts/run.sh test
./tests/scripts/run.sh test SUITE=fast
./tests/scripts/run.sh test SUITE=live
./tests/scripts/run.sh test SCENARIO=existing_cluster/invalid_empty_cluster_ocid
./tests/scripts/run.sh test SUITE=all SCENARIO=networking/invalid_ocid_format
./tests/scripts/run.sh fixture ACTION=status TARGET=basic
./tests/scripts/run.sh fixture ACTION=refresh TARGET=enhanced USE_CUSTOM_CLOUD_INIT=false
./tests/scripts/run.sh debug TARGET=enhanced
```

## Notes

- `test` defaults to `SUITE=fast`, runs blocking root preflight checks first, and then runs the selected suite.
- Blocking preflight currently includes `terraform init -backend=false -input=false` and `terraform validate`.
- The fast suite intentionally uses scenario validation and not `terraform test`.
- `test` runs aggregate scenario failures and report a final summary instead of stopping on the first failing case.
- The fixture directories are now isolated under `tests/fixtures/`.
- The enhanced fixture accepts `USE_CUSTOM_CLOUD_INIT=true|false` so we can test both the default OKE bootstrap and the stack's custom OCIR bootstrap.
- When `test_mode = true`, the stack exposes extra non-sensitive metadata through `terraform output -json` for local inspection tooling.
- Successful `test` and `fixture` runs clean up their timestamped artifact directories by default. Set `TESTS_KEEP_SUCCESS_ARTIFACTS=true` if you want to retain successful logs locally.
- `SUITE=fast` is the CI-safe subset used on pull requests and includes only scenarios explicitly tagged in `suites.txt` that fail before live OCI access is needed.
- `SUITE=live` is the local OCI-backed subset for fixture-based existing-cluster compatibility checks.
- `tests/.env` and `tests/.env.local` are ignored by git and are the right place for real local test values.
- `make debug TARGET=...` resolves DevOps runtime IDs from `terraform output -json` first and only uses `PROJECT_ID`, `PIPELINE_ID`, or `DEPLOYMENT_ID` as optional manual overrides.
