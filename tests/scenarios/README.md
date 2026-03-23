# Scenario validation (Terraform 1.5-compatible)

This repo uses **scenario-based validation** instead of `terraform test` so it can run on Terraform 1.5.x (Resource Manager).

Each scenario provides either a tracked `terraform.tfvars` file, a `prepare.sh` script that renders `terraform.tfvars` from local fixture outputs, or a `run.sh` script for multi-step flows. Scenario metadata can live in `scenario.json` and is preferred when present.

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
- Scenarios can optionally declare `scenario.json`, `fixture.env`, `expression.tfconsole`, `mode.txt`, `plan_targets.txt`, `expected_error.txt`, `suites.txt`, and `run.sh`.
- `scenario.json` is the preferred metadata source for `mode`, `expectation`, `suites`, `expected_error`, `expected_output`, `plan_targets`, `cleanup_policy`, and `destroy_after_run`.
- Legacy sidecar metadata files remain supported during migration when `scenario.json` is absent.
- If both `scenario.json` and legacy metadata files exist, the manifest wins for overlapping fields.
- `mode` may be `script` for multi-step scenario flows driven by `run.sh`.
- `cleanup_policy` may be `always`, `success`, or `never`. Legacy `destroy_after_run: true` still maps to `always`.
- `SUITE=fast` runs only scenarios explicitly tagged with `fast` in `scenario.json` or `suites.txt`.
- `SUITE=live` runs only scenarios explicitly tagged with `live` in `scenario.json` or `suites.txt`.
- The fast suite is intentionally limited to offline validation failures that happen before OCI provider authentication or live data lookups.
- The script exits non-zero if any scenario behaves unexpectedly.

## Current scenario areas

- `deployment/`
- `networking/`
- `existing_cluster/`
- `managed_cluster/`
