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
make test SCENARIO=networking/valid_existing_vcn

make fixture ACTION=status TARGET=network
make fixture ACTION=up TARGET=enhanced
make fixture ACTION=scale TARGET=enhanced SIZE=3
make fixture ACTION=refresh TARGET=enhanced USE_CUSTOM_CLOUD_INIT=false

make debug TARGET=enhanced
```

Direct runner usage:

```bash
./tests/scripts/run.sh test
./tests/scripts/run.sh test SCENARIO=networking/invalid_ocid_format
./tests/scripts/run.sh fixture ACTION=status TARGET=basic
./tests/scripts/run.sh fixture ACTION=refresh TARGET=enhanced USE_CUSTOM_CLOUD_INIT=false
./tests/scripts/run.sh debug TARGET=enhanced
```

## Notes

- The fast suite intentionally uses scenario validation and not `terraform test`.
- The fixture directories are now isolated under `tests/fixtures/`.
- The enhanced fixture accepts `USE_CUSTOM_CLOUD_INIT=true|false` so we can test both the default OKE bootstrap and the stack's custom OCIR bootstrap.
- When `test_mode = true`, the stack exposes extra non-sensitive metadata through `terraform output -json` for local inspection tooling.
- Successful `test` and `fixture` runs clean up their timestamped artifact directories by default. Set `TESTS_KEEP_SUCCESS_ARTIFACTS=true` if you want to retain successful logs locally.
- `tests/.env` and `tests/.env.local` are ignored by git and are the right place for real local test values.
