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
- `scenario.json` is the preferred metadata source for `mode`, `expectation`, `suites`, `expected_error`, `expected_output`, `plan_targets`, `cleanup_policy`, `destroy_after_run`, and live-suite `infra` metadata.
- Legacy sidecar metadata files remain supported during migration when `scenario.json` is absent.
- If both `scenario.json` and legacy metadata files exist, the manifest wins for overlapping fields.
- `mode` may be `script` for multi-step scenario flows driven by `run.sh`.
- `cleanup_policy` may be `always`, `success`, or `never`. Legacy `destroy_after_run: true` still maps to `always`.
- `SUITE=fast` runs only scenarios explicitly tagged with `fast` in `scenario.json` or `suites.txt`.
- `SUITE=live` runs only scenarios explicitly tagged with `live` in `scenario.json` or `suites.txt`.
- Live scenarios may declare `infra.profile` plus `infra.bootstrap`. The runner groups `SUITE=live` scenarios by profile in first-seen order, reuses compatible fixture state within a group, and reconciles fixture targets only when the next group requires different infra.
- `infra.bootstrap` is an ordered list of fixture actions. Current supported fields are `target`, `action`, `size`, `use_custom_cloud_init`, and `is_public_endpoint`.
- `fixture.env` remains a fallback for unmigrated scenarios, but manifest `infra` is the source of truth when both are present.
- Set `LIVE_FIXTURE_FINAL_CLEANUP=success` if you want a successful live suite to destroy all touched fixture targets after the run. The default is `never`, which leaves the last prepared profile warm.
- The fast suite is intentionally limited to offline validation failures that happen before OCI provider authentication or live data lookups.
- The script exits non-zero if any scenario behaves unexpectedly.

## Current scenario areas

- `deployment/`
- `networking/`
- `existing_cluster/`
- `managed_cluster/`
