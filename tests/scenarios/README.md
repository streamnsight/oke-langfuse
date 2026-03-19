# Scenario validation (Terraform 1.5-compatible)

This repo uses **scenario-based validation** instead of `terraform test` so it can run on Terraform 1.5.x (Resource Manager).

Each scenario provides a `terraform.tfvars` file and is executed via `terraform validate` to ensure feature/flag coherence.

## Run locally

```bash
./tests/scripts/run.sh test
./tests/scripts/run.sh test SCENARIO=networking/valid_existing_vcn
```

## Conventions
- `valid_*` directories must validate successfully.
- `invalid_*` directories are expected to fail validation.
- The script exits non-zero if any scenario behaves unexpectedly.
