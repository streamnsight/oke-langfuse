#!/usr/bin/env bash

scenario_expectation() {
  local scenario_name="$1"
  case "$(basename "$scenario_name")" in
    valid_*)
      printf 'pass\n'
      ;;
    invalid_*)
      printf 'fail\n'
      ;;
    *)
      die "Cannot infer expectation for scenario: $scenario_name"
      ;;
  esac
}

resolve_scenarios() {
  local selector="${1:-}"
  if [ -z "$selector" ]; then
    find "$TESTS_DIR/scenarios" -type f -name terraform.tfvars -print | sort | xargs -n1 dirname
    return
  fi

  local matches=()
  while IFS= read -r path; do
    matches+=("$path")
  done < <(find "$TESTS_DIR/scenarios" -type f -name terraform.tfvars -print | xargs -n1 dirname | sort | grep -E "/${selector}$|/${selector}/|/${selector}$" || true)

  if [ "${#matches[@]}" -eq 0 ]; then
    die "No scenario matched selector: $selector"
  fi
  if [ "${#matches[@]}" -gt 1 ]; then
    printf '%s\n' "${matches[@]}" >&2
    die "Scenario selector is ambiguous: $selector"
  fi

  printf '%s\n' "${matches[0]}"
}

copy_repo_for_scenario() {
  local destination="$1"
  rsync -a \
    --exclude ".git" \
    --exclude ".terraform" \
    --exclude "terraform.tfvars" \
    --exclude "terraform.tfvars.json" \
    --exclude "tests/artifacts" \
    "$ROOT_DIR/" "$destination/" >/dev/null
}

capture_terraform_outputs() {
  local workdir="$1"
  local outfile="$2"
  if [ -f "$workdir/terraform.tfstate" ]; then
    terraform -chdir="$workdir" output -json >"$outfile" 2>/dev/null || true
  else
    printf '{}\n' >"$outfile"
  fi
}

run_single_scenario() {
  local scenario_dir="$1"
  local scenario_name="${scenario_dir#"$TESTS_DIR/scenarios/"}"
  local expectation
  expectation="$(scenario_expectation "$scenario_dir")"
  local artifact_dir
  artifact_dir="$(create_artifact_dir "test/$(slugify "$scenario_name")")"
  local work_dir
  work_dir="$(mktemp -d)"
  local init_log="$artifact_dir/terraform-init.log"
  local console_log="$artifact_dir/terraform-console.log"
  local outputs_before="$artifact_dir/outputs-before.json"
  local outputs_after="$artifact_dir/outputs-after.json"

  log "Running scenario $scenario_name (expect: $expectation)"
  copy_repo_for_scenario "$work_dir"
  cp "$scenario_dir/terraform.tfvars" "$work_dir/terraform.tfvars"

  capture_terraform_outputs "$work_dir" "$outputs_before"

  if ! terraform -chdir="$work_dir" init -backend=false -input=false >"$init_log" 2>&1; then
    rm -rf "$work_dir"
    die "terraform init failed for scenario: $scenario_name (see $init_log)"
  fi

  local console_output
  console_output="$(terraform -chdir="$work_dir" console -var-file="terraform.tfvars" <<<"true" 2>&1 || true)"
  printf '%s\n' "$console_output" >"$console_log"
  capture_terraform_outputs "$work_dir" "$outputs_after"

  local has_error="false"
  if printf '%s\n' "$console_output" | grep -q "Error:"; then
    has_error="true"
  fi

  if [ "$expectation" = "pass" ] && [ "$has_error" = "true" ]; then
    cat "$console_log" >&2
    rm -rf "$work_dir"
    die "Scenario was expected to pass but failed: $scenario_name"
  fi

  if [ "$expectation" = "fail" ] && [ "$has_error" = "false" ]; then
    rm -rf "$work_dir"
    die "Scenario was expected to fail but succeeded: $scenario_name"
  fi

  log "Scenario completed: $scenario_name"
  rm -rf "$work_dir"
}

run_scenario_suite() {
  ensure_artifacts_dir
  require_command terraform
  require_command rsync

  local selector="${1:-}"
  local ran_any="false"
  while IFS= read -r scenario_dir; do
    [ -n "$scenario_dir" ] || continue
    ran_any="true"
    run_single_scenario "$scenario_dir"
  done < <(resolve_scenarios "$selector")

  if [ "$ran_any" != "true" ]; then
    die "No scenarios were executed"
  fi

  log "Scenario suite completed."
}
