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
  local scenario_roots_cmd=(find "$TESTS_DIR/scenarios" -type f \( -name terraform.tfvars -o -name prepare.sh \) -print)
  if [ -z "$selector" ]; then
    "${scenario_roots_cmd[@]}" | sort | xargs -n1 dirname | awk '!seen[$0]++'
    return
  fi

  local matches=()
  while IFS= read -r path; do
    matches+=("$path")
  done < <("${scenario_roots_cmd[@]}" | sort | xargs -n1 dirname | awk '!seen[$0]++' | grep -E "/${selector}$|/${selector}/|/${selector}$" || true)

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
    --exclude "tests/.env" \
    --exclude "tests/.env.local" \
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

terraform_provider_runtime_hint() {
  local log_file="$1"
  if grep -q "Unrecognized remote plugin message" "$log_file" 2>/dev/null; then
    printf ' Terraform provider startup failed; this usually means the current environment cannot execute provider plugins even though init succeeded.\n'
  fi
}

scenario_mode() {
  local scenario_dir="$1"
  if [ -f "$scenario_dir/mode.txt" ]; then
    tr -d '[:space:]' <"$scenario_dir/mode.txt"
  else
    printf 'console\n'
  fi
}

scenario_console_expression() {
  local scenario_dir="$1"
  if [ -f "$scenario_dir/expression.tfconsole" ]; then
    cat "$scenario_dir/expression.tfconsole"
  else
    printf 'true\n'
  fi
}

scenario_expected_error() {
  local scenario_dir="$1"
  if [ -f "$scenario_dir/expected_error.txt" ]; then
    cat "$scenario_dir/expected_error.txt"
  fi
}

scenario_plan_targets() {
  local scenario_dir="$1"
  if [ -f "$scenario_dir/plan_targets.txt" ]; then
    sed '/^[[:space:]]*$/d' "$scenario_dir/plan_targets.txt"
  fi
}

prepare_fixture_for_scenario() {
  local scenario_dir="$1"
  [ -f "$scenario_dir/fixture.env" ] || return 0

  (
    unset TARGET ACTION SIZE USE_CUSTOM_CLOUD_INIT IS_PUBLIC_ENDPOINT
    # shellcheck disable=SC1090
    source "$scenario_dir/fixture.env"
    require_non_empty "${TARGET:-}" "TARGET is required in $scenario_dir/fixture.env"
    require_non_empty "${ACTION:-}" "ACTION is required in $scenario_dir/fixture.env"
    run_fixture_action "${TARGET:-}" "${ACTION:-}" "${SIZE:-}"
  )
}

prepare_scenario_workdir() {
  local scenario_dir="$1"
  local scenario_name="$2"
  local work_dir="$3"

  if [ -f "$scenario_dir/prepare.sh" ]; then
    bash "$work_dir/tests/scenarios/$scenario_name/prepare.sh" "$work_dir"
  else
    cp "$scenario_dir/terraform.tfvars" "$work_dir/terraform.tfvars"
  fi
}

run_single_scenario() {
  local scenario_dir="$1"
  local scenario_name="${scenario_dir#"$TESTS_DIR/scenarios/"}"
  local expectation
  expectation="$(scenario_expectation "$scenario_dir")"
  local mode
  mode="$(scenario_mode "$scenario_dir")"
  local expected_error
  expected_error="$(scenario_expected_error "$scenario_dir")"
  local artifact_dir
  artifact_dir="$(create_artifact_dir "test/$(slugify "$scenario_name")")"
  local work_dir
  work_dir="$(mktemp -d)"
  local init_log="$artifact_dir/terraform-init.log"
  local run_log="$artifact_dir/terraform-$mode.log"
  local outputs_before="$artifact_dir/outputs-before.json"
  local outputs_after="$artifact_dir/outputs-after.json"

  log "Running scenario $scenario_name (expect: $expectation, mode: $mode)"
  prepare_fixture_for_scenario "$scenario_dir"
  copy_repo_for_scenario "$work_dir"
  prepare_scenario_workdir "$scenario_dir" "$scenario_name" "$work_dir"

  capture_terraform_outputs "$work_dir" "$outputs_before"

  local init_args=()
  while IFS= read -r arg; do
    [ -n "$arg" ] && init_args+=("$arg")
  done < <(terraform_init_args)

  if ! terraform -chdir="$work_dir" init "${init_args[@]}" >"$init_log" 2>&1; then
    rm -rf "$work_dir"
    die "terraform init failed for scenario: $scenario_name (see $init_log)"
  fi

  local command_output=""
  local has_error="false"

  case "$mode" in
    console)
      local expression
      expression="$(scenario_console_expression "$scenario_dir")"
      command_output="$(terraform -chdir="$work_dir" console -var-file="terraform.tfvars" <<<"$expression" 2>&1 || true)"
      printf '%s\n' "$command_output" >"$run_log"
      if printf '%s\n' "$command_output" | grep -q "Error:"; then
        has_error="true"
      fi
      ;;
    plan)
      local plan_args=(-input=false -lock=false -no-color -var-file="terraform.tfvars")
      while IFS= read -r target; do
        [ -n "$target" ] || continue
        plan_args+=("-target=$target")
      done < <(scenario_plan_targets "$scenario_dir")

      if terraform -chdir="$work_dir" plan "${plan_args[@]}" >"$run_log" 2>&1; then
        has_error="false"
      else
        has_error="true"
      fi
      command_output="$(cat "$run_log")"
      ;;
    *)
      rm -rf "$work_dir"
      die "Unsupported scenario mode '$mode' for $scenario_name"
      ;;
  esac

  capture_terraform_outputs "$work_dir" "$outputs_after"

  if [ -n "$expected_error" ] && [ "$has_error" = "true" ]; then
    if ! printf '%s\n' "$command_output" | grep -Fq -- "$expected_error"; then
      cat "$run_log" >&2
      rm -rf "$work_dir"
      die "Scenario failed, but not with the expected error text: $scenario_name"
    fi
  fi

  if [ "$expectation" = "pass" ] && [ "$has_error" = "true" ]; then
    cat "$run_log" >&2
    rm -rf "$work_dir"
    die "Scenario was expected to pass but failed: $scenario_name.$(terraform_provider_runtime_hint "$run_log")"
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
