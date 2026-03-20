# Scenario validation (Terraform 1.5-compatible)

This repo uses **scenario-based validation** instead of `terraform test` so it can run on Terraform 1.5.x (Resource Manager).

Each scenario provides either a tracked `terraform.tfvars` file or a `prepare.sh` script that renders `terraform.tfvars` from local fixture outputs.

## Run locally

```bash
./tests/scripts/run.sh test
./tests/scripts/run.sh test SUITE=fast
./tests/scripts/run.sh test SCENARIO=networking/valid_existing_vcn
```

## Conventions
- `valid_*` directories must validate successfully.
- `invalid_*` directories are expected to fail validation.
- Scenarios can optionally declare `fixture.env`, `expression.tfconsole`, `mode.txt`, `plan_targets.txt`, and `expected_error.txt`.
- `SUITE=fast` runs only tracked-`terraform.tfvars` scenarios that do not depend on fixture preparation.
- The fast suite intentionally avoids `terraform console` and uses targeted `plan` checks so PR validation never waits on interactive console behavior.
- The script exits non-zero if any scenario behaves unexpectedly.

## Current scenario areas

- `networking/`
- `existing_cluster/`
