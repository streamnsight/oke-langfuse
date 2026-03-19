# Test Workspace

This repository keeps test tooling under `./tests` so it stays separate from stack-owned scripts under `./scripts`.

## Layout

- `tests/scripts/` contains the test runner and helper libraries
- `tests/scenarios/` contains fast scenario-based validation inputs
- `tests/fixtures/` contains reusable fixture workspaces and examples
- `tests/artifacts/` stores generated test outputs and debug snapshots

## Commands

From the repo root:

```bash
make test
make test SCENARIO=networking/valid_existing_vcn

make fixture ACTION=status TARGET=network
make fixture ACTION=up TARGET=enhanced
make fixture ACTION=scale TARGET=enhanced SIZE=3

make debug TARGET=enhanced
```

Direct runner usage:

```bash
./tests/scripts/run.sh test
./tests/scripts/run.sh test SCENARIO=networking/invalid_ocid_format
./tests/scripts/run.sh fixture ACTION=status TARGET=basic
./tests/scripts/run.sh debug TARGET=enhanced
```

## Notes

- The fast suite intentionally uses scenario validation and not `terraform test`.
- The fixture directories are now isolated under `tests/fixtures/`.
- When `test_mode = true`, the stack exposes extra non-sensitive metadata through `terraform output -json` for local inspection tooling.
