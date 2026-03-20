# Scenario validation (Terraform 1.5-compatible)

This repo uses **scenario-based validation** instead of `terraform test` so it can run on Terraform 1.5.x (Resource Manager).

Each scenario provides either a tracked `terraform.tfvars` file or a `prepare.sh` script that renders `terraform.tfvars` from local fixture outputs.

## Run locally

```bash
./tests/scripts/run.sh test
./tests/scripts/run.sh test SUITE=fast
./tests/scripts/run.sh test SUITE=live
./tests/scripts/run.sh test SCENARIO=existing_cluster/invalid_empty_cluster_ocid
./tests/scripts/run.sh test SUITE=all SCENARIO=networking/valid_existing_vcn
```

## Conventions
- `valid_*` directories must validate successfully.
- `invalid_*` directories are expected to fail validation.
- Scenarios can optionally declare `fixture.env`, `expression.tfconsole`, `mode.txt`, `plan_targets.txt`, `expected_error.txt`, and `suites.txt`.
- `SUITE=fast` runs only scenarios explicitly tagged with `fast` in `suites.txt`.
- `SUITE=live` runs only scenarios explicitly tagged with `live` in `suites.txt`.
- The fast suite is intentionally limited to offline validation failures that happen before OCI provider authentication or live data lookups.
- The script exits non-zero if any scenario behaves unexpectedly.

## Current scenario areas

- `networking/`
- `existing_cluster/`
