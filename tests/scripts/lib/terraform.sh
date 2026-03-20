#!/usr/bin/env bash

scenario_manifest_path() {
  local scenario_dir="$1"
  printf '%s/scenario.json\n' "$scenario_dir"
}

scenario_has_manifest() {
  local scenario_dir="$1"
  [ -f "$(scenario_manifest_path "$scenario_dir")" ]
}

scenario_json_get_raw() {
  local scenario_dir="$1"
  local jq_filter="$2"
  jq -r "$jq_filter" "$(scenario_manifest_path "$scenario_dir")"
}

scenario_json_get_string() {
  local scenario_dir="$1"
  local jq_filter="$2"
  local value
  value="$(scenario_json_get_raw "$scenario_dir" "$jq_filter // empty")"
  if [ "$value" = "null" ]; then
    return 1
  fi
  printf '%s\n' "$value"
}

scenario_json_get_bool() {
  local scenario_dir="$1"
  local jq_filter="$2"
  local value
  value="$(scenario_json_get_raw "$scenario_dir" "$jq_filter // false")"
  case "$value" in
    true|false)
      printf '%s\n' "$value"
      ;;
    *)
      die "Expected boolean from scenario manifest for $scenario_dir: $jq_filter"
      ;;
  esac
}

scenario_json_get_array_lines() {
  local scenario_dir="$1"
  local jq_filter="$2"
  scenario_json_get_raw "$scenario_dir" "$jq_filter // [] | .[]"
}

scenario_expectation() {
  local scenario_name="$1"
  if scenario_has_manifest "$scenario_name"; then
    local manifest_expectation
    manifest_expectation="$(scenario_json_get_string "$scenario_name" '.expectation')" || manifest_expectation=""
    if [ -n "$manifest_expectation" ]; then
      printf '%s\n' "$manifest_expectation"
      return
    fi
  fi
  if [ -f "$scenario_name/expectation.txt" ]; then
    tr -d '[:space:]' <"$scenario_name/expectation.txt"
    return
  fi
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
  local scenario_roots_cmd=(find "$TESTS_DIR/scenarios" -type f \( -name terraform.tfvars -o -name prepare.sh -o -name run.sh -o -name scenario.json \) -print)
  local all_scenarios_cmd=("${scenario_roots_cmd[@]}")
  local scenario_dirs
  scenario_dirs="$("${all_scenarios_cmd[@]}" | sort | xargs -n1 dirname | awk '!seen[$0]++')"

  if [ -n "${SUITE:-}" ]; then
    scenario_dirs="$(filter_scenarios_by_suite "$scenario_dirs" "${SUITE:-}")"
  fi

  if [ -z "$selector" ]; then
    printf '%s\n' "$scenario_dirs"
    return
  fi

  local matches=()
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    local relative_path="${path#"$TESTS_DIR/scenarios/"}"
    if [ "$relative_path" = "$selector" ] || [ "$(basename "$relative_path")" = "$selector" ]; then
      matches+=("$path")
    fi
  done < <(printf '%s\n' "$scenario_dirs")

  if [ "${#matches[@]}" -eq 0 ]; then
    die "No scenario matched selector: $selector"
  fi
  if [ "${#matches[@]}" -gt 1 ]; then
    printf '%s\n' "${matches[@]}" >&2
    die "Scenario selector is ambiguous: $selector"
  fi

  printf '%s\n' "${matches[0]}"
}

scenario_has_suite_tag() {
  local scenario_dir="$1"
  local suite="$2"
  if scenario_has_manifest "$scenario_dir"; then
    local manifest_suite
    while IFS= read -r manifest_suite; do
      [ -n "$manifest_suite" ] || continue
      if [ "$manifest_suite" = "$suite" ]; then
        return 0
      fi
    done < <(scenario_json_get_array_lines "$scenario_dir" '.suites')
    return 1
  fi
  local suites_file="$scenario_dir/suites.txt"
  [ -f "$suites_file" ] || return 1
  grep -Eq "(^|[[:space:]])${suite}($|[[:space:]])" "$suites_file"
}

filter_scenarios_by_suite() {
  local scenario_dirs="$1"
  local suite="$2"

  case "$suite" in
    all|"")
      printf '%s\n' "$scenario_dirs"
      ;;
    fast)
      while IFS= read -r scenario_dir; do
        [ -n "$scenario_dir" ] || continue
        if scenario_has_suite_tag "$scenario_dir" fast; then
          printf '%s\n' "$scenario_dir"
        fi
      done <<<"$scenario_dirs"
      ;;
    live)
      while IFS= read -r scenario_dir; do
        [ -n "$scenario_dir" ] || continue
        if scenario_has_suite_tag "$scenario_dir" live; then
          printf '%s\n' "$scenario_dir"
        fi
      done <<<"$scenario_dirs"
      ;;
    *)
      die "Unknown scenario suite: $suite"
      ;;
  esac
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

normalize_whitespace() {
  tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'
}

scenario_mode() {
  local scenario_dir="$1"
  if scenario_has_manifest "$scenario_dir"; then
    local manifest_mode
    manifest_mode="$(scenario_json_get_string "$scenario_dir" '.mode')" || manifest_mode=""
    if [ -n "$manifest_mode" ]; then
      printf '%s\n' "$manifest_mode"
      return
    fi
  fi
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
  if scenario_has_manifest "$scenario_dir"; then
    scenario_json_get_string "$scenario_dir" '.expected_error' || true
    return
  fi
  if [ -f "$scenario_dir/expected_error.txt" ]; then
    cat "$scenario_dir/expected_error.txt"
  fi
}

scenario_expected_output() {
  local scenario_dir="$1"
  if scenario_has_manifest "$scenario_dir"; then
    scenario_json_get_string "$scenario_dir" '.expected_output' || true
    return
  fi
  if [ -f "$scenario_dir/expected_output.txt" ]; then
    cat "$scenario_dir/expected_output.txt"
  fi
}

scenario_targets() {
  local scenario_dir="$1"
  if scenario_has_manifest "$scenario_dir"; then
    scenario_json_get_array_lines "$scenario_dir" '.plan_targets'
    return
  fi
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
  elif [ -f "$scenario_dir/terraform.tfvars" ]; then
    cp "$scenario_dir/terraform.tfvars" "$work_dir/terraform.tfvars"
  fi
}

run_logged_command() {
  local logfile="$1"
  shift

  if should_stream_logs; then
    set +e
    "$@" 2>&1 | tee "$logfile"
    local status=${PIPESTATUS[0]}
    set -e
    return "$status"
  fi

  "$@" >"$logfile" 2>&1
}

run_preflight_checks() {
  local artifact_dir
  artifact_dir="$(create_artifact_dir "preflight")"
  local init_log="$artifact_dir/terraform-init.log"
  local validate_log="$artifact_dir/terraform-validate.log"

  local init_args=()
  while IFS= read -r arg; do
    [ -n "$arg" ] && init_args+=("$arg")
  done < <(terraform_init_args)

  log "Running preflight checks"

  begin_log_group "Preflight: terraform init"
  if ! run_logged_command "$init_log" terraform -chdir="$ROOT_DIR" init "${init_args[@]}"; then
    [ -s "$init_log" ] && cat "$init_log" >&2
    end_log_group
    die "Preflight failed during terraform init (see $init_log)"
  fi
  end_log_group

  begin_log_group "Preflight: terraform validate"
  if ! run_logged_command "$validate_log" terraform -chdir="$ROOT_DIR" validate -no-color; then
    [ -s "$validate_log" ] && cat "$validate_log" >&2
    end_log_group
    die "Preflight failed during terraform validate (see $validate_log)"
  fi
  end_log_group

  log "Preflight completed."
  cleanup_artifact_dir_on_success "$artifact_dir"
}

run_single_scenario() {
  local scenario_dir="$1"
  local scenario_name="${scenario_dir#"$TESTS_DIR/scenarios/"}"
  TESTS_LAST_SCENARIO_RESULT=""
  local expectation
  expectation="$(scenario_expectation "$scenario_dir")"
  local mode raw_mode destroy_after_run
  raw_mode="$(scenario_mode "$scenario_dir")"
  mode="$raw_mode"
  if scenario_has_manifest "$scenario_dir"; then
    destroy_after_run="$(scenario_json_get_bool "$scenario_dir" '.destroy_after_run')"
  else
    destroy_after_run="false"
  fi
  if [[ "$mode" == *-destroy ]]; then
    destroy_after_run="true"
    mode="${mode%-destroy}"
  fi
  local expected_error
  expected_error="$(scenario_expected_error "$scenario_dir")"
  local expected_output
  expected_output="$(scenario_expected_output "$scenario_dir")"
  local artifact_dir
  artifact_dir="$(create_artifact_dir "test/$(slugify "$scenario_name")")"
  local work_dir
  work_dir="$(mktemp -d)"
  local init_log="$artifact_dir/terraform-init.log"
  local run_log="$artifact_dir/terraform-$mode.log"
  local destroy_log="$artifact_dir/terraform-destroy.log"
  local outputs_before="$artifact_dir/outputs-before.json"
  local outputs_after="$artifact_dir/outputs-after.json"
  local failure_message=""
  local cleanup_failed="false"
  local cleanup_failure_message=""
  local destroy_args=(-input=false -lock=false -no-color -var-file="terraform.tfvars")

  log "Running scenario $scenario_name (expect: $expectation, mode: $raw_mode)"
  prepare_fixture_for_scenario "$scenario_dir"
  copy_repo_for_scenario "$work_dir"
  prepare_scenario_workdir "$scenario_dir" "$scenario_name" "$work_dir"

  capture_terraform_outputs "$work_dir" "$outputs_before"

  local init_args=()
  while IFS= read -r arg; do
    [ -n "$arg" ] && init_args+=("$arg")
  done < <(terraform_init_args)

  begin_log_group "Scenario $scenario_name: terraform init"
  if ! run_logged_command "$init_log" terraform -chdir="$work_dir" init "${init_args[@]}"; then
    if [ ! -s "$init_log" ]; then
      printf '[tests] terraform init produced no captured output for %s\n' "$scenario_name" >&2
    fi
    cat "$init_log" >&2
    end_log_group
    failure_message="terraform init failed (see $init_log)"
    rm -rf "$work_dir"
    printf '%s\n' "$failure_message" >"$artifact_dir/failure.txt"
    log "Scenario failed: $scenario_name"
    TESTS_LAST_SCENARIO_RESULT="$scenario_name|$failure_message"
    return 1
  fi
  end_log_group

  local command_output=""
  local has_error="false"

  case "$mode" in
    console)
      local expression
      expression="$(scenario_console_expression "$scenario_dir")"
      begin_log_group "Scenario $scenario_name: terraform console"
      if should_stream_logs; then
        set +e
        command_output="$(terraform -chdir="$work_dir" console -var-file="terraform.tfvars" <<<"$expression" 2>&1 | tee "$run_log")"
        local console_status=${PIPESTATUS[0]}
        set -e
      else
        set +e
        command_output="$(terraform -chdir="$work_dir" console -var-file="terraform.tfvars" <<<"$expression" 2>&1)"
        local console_status=$?
        set -e
        printf '%s\n' "$command_output" >"$run_log"
      fi
      end_log_group
      if printf '%s\n' "$command_output" | grep -q "Error:"; then
        has_error="true"
      elif [ "${console_status:-0}" -ne 0 ]; then
        has_error="true"
      fi
      ;;
    plan|apply|apply-console)
      local plan_args=(-input=false -lock=false -no-color -var-file="terraform.tfvars")
      local target_args=()
      local target
      while IFS= read -r target; do
        [ -n "$target" ] || continue
        target_args+=("-target=$target")
        plan_args+=("-target=$target")
      done < <(scenario_targets "$scenario_dir")

      if [ "$mode" = "plan" ]; then
        begin_log_group "Scenario $scenario_name: terraform plan"
        if run_logged_command "$run_log" terraform -chdir="$work_dir" plan "${plan_args[@]}"; then
          has_error="false"
        else
          has_error="true"
        fi
        end_log_group
      elif [ "$mode" = "apply" ]; then
        begin_log_group "Scenario $scenario_name: terraform apply"
        if run_logged_command "$run_log" terraform -chdir="$work_dir" apply "${plan_args[@]}" -auto-approve; then
          has_error="false"
        else
          has_error="true"
        fi
        end_log_group
      else
        local singular_node_pool_target="-target=data.oci_containerengine_node_pool.target"
        local needs_staged_apply="false"
        local staged_target_args=()
        local target_arg
        local expression
        expression="$(scenario_console_expression "$scenario_dir")"
        for target_arg in "${target_args[@]}"; do
          if [ "$target_arg" = "$singular_node_pool_target" ]; then
            needs_staged_apply="true"
            continue
          fi
          staged_target_args+=("$target_arg")
        done

        local apply_succeeded="false"
        if [ "$needs_staged_apply" = "true" ]; then
          begin_log_group "Scenario $scenario_name: staged terraform apply"
          if should_stream_logs; then
            set +e
            {
              printf '[tests] staged apply phase 1\n'
              terraform -chdir="$work_dir" apply -input=false -lock=false -no-color -var-file="terraform.tfvars" "${staged_target_args[@]}" -auto-approve
              printf '\n[tests] staged apply phase 2\n'
              terraform -chdir="$work_dir" apply "${plan_args[@]}" -auto-approve
            } 2>&1 | tee "$run_log"
            local apply_status=${PIPESTATUS[0]}
            set -e
          else
            set +e
            {
              printf '[tests] staged apply phase 1\n'
              terraform -chdir="$work_dir" apply -input=false -lock=false -no-color -var-file="terraform.tfvars" "${staged_target_args[@]}" -auto-approve
              printf '\n[tests] staged apply phase 2\n'
              terraform -chdir="$work_dir" apply "${plan_args[@]}" -auto-approve
            } >"$run_log" 2>&1
            local apply_status=$?
            set -e
          fi
          end_log_group
          [ "$apply_status" -eq 0 ] && apply_succeeded="true"
        else
          begin_log_group "Scenario $scenario_name: terraform apply"
          if run_logged_command "$run_log" terraform -chdir="$work_dir" apply "${plan_args[@]}" -auto-approve; then
            apply_succeeded="true"
          fi
          end_log_group
        fi

        if [ "$apply_succeeded" = "true" ]; then
          begin_log_group "Scenario $scenario_name: terraform console"
          if should_stream_logs; then
            set +e
            local console_output
            console_output="$(terraform -chdir="$work_dir" console -var-file="terraform.tfvars" <<<"$expression" 2>&1 | tee -a "$run_log")"
            local console_status=${PIPESTATUS[0]}
            set -e
          else
            local console_output
            set +e
            console_output="$(terraform -chdir="$work_dir" console -var-file="terraform.tfvars" <<<"$expression" 2>&1)"
            local console_status=$?
            set -e
            printf '\n%s\n' "$console_output" >>"$run_log"
          fi
          end_log_group
          command_output="$console_output"
          if printf '%s\n' "$console_output" | grep -q "Error:"; then
            has_error="true"
          elif [ "${console_status:-0}" -ne 0 ]; then
            has_error="true"
          else
            has_error="false"
          fi
        else
          has_error="true"
        fi
      fi
      if [ -z "$command_output" ]; then
        command_output="$(cat "$run_log")"
      fi
      ;;
    script)
      begin_log_group "Scenario $scenario_name: custom script"
      if should_stream_logs; then
        set +e
        bash "$work_dir/tests/scenarios/$scenario_name/run.sh" "$work_dir" 2>&1 | tee "$run_log"
        local script_status=${PIPESTATUS[0]}
        set -e
      else
        set +e
        bash "$work_dir/tests/scenarios/$scenario_name/run.sh" "$work_dir" >"$run_log" 2>&1
        local script_status=$?
        set -e
      fi
      end_log_group
      command_output="$(cat "$run_log")"
      if [ "${script_status:-0}" -ne 0 ]; then
        has_error="true"
      fi
      ;;
    *)
      rm -rf "$work_dir"
      die "Unsupported scenario mode '$mode' for $scenario_name"
      ;;
  esac

  capture_terraform_outputs "$work_dir" "$outputs_after"

  if [ "$destroy_after_run" = "true" ] && [ -f "$work_dir/terraform.tfstate" ]; then
    begin_log_group "Scenario $scenario_name: terraform destroy"
    if ! run_logged_command "$destroy_log" terraform -chdir="$work_dir" destroy "${destroy_args[@]}" -auto-approve; then
      cleanup_failed="true"
      cleanup_failure_message="terraform destroy failed after scenario execution"
      [ -s "$destroy_log" ] && cat "$destroy_log" >&2
    fi
    end_log_group
  fi

  if [ -n "$expected_output" ] && [ "$has_error" = "false" ]; then
    local normalized_output normalized_expected_output
    normalized_output="$(printf '%s\n' "$command_output" | normalize_whitespace)"
    normalized_expected_output="$(printf '%s\n' "$expected_output" | normalize_whitespace)"
    if [[ "$normalized_output" != *"$normalized_expected_output"* ]]; then
      cat "$run_log" >&2
      failure_message="output did not contain expected text"
      rm -rf "$work_dir"
      printf '%s\n' "$failure_message" >"$artifact_dir/failure.txt"
      log "Scenario failed: $scenario_name"
      TESTS_LAST_SCENARIO_RESULT="$scenario_name|$failure_message"
      return 1
    fi
  fi

  if [ -n "$expected_error" ] && [ "$has_error" = "true" ]; then
    local normalized_output normalized_expected
    normalized_output="$(printf '%s\n' "$command_output" | normalize_whitespace)"
    normalized_expected="$(printf '%s\n' "$expected_error" | normalize_whitespace)"
    if [[ "$normalized_output" != *"$normalized_expected"* ]]; then
      cat "$run_log" >&2
      failure_message="failed, but not with the expected error text"
      rm -rf "$work_dir"
      printf '%s\n' "$failure_message" >"$artifact_dir/failure.txt"
      log "Scenario failed: $scenario_name"
      TESTS_LAST_SCENARIO_RESULT="$scenario_name|$failure_message"
      return 1
    fi
  fi

  if [ "$expectation" = "pass" ] && [ "$has_error" = "true" ]; then
    cat "$run_log" >&2
    failure_message="expected pass but failed.$(terraform_provider_runtime_hint "$run_log")"
    rm -rf "$work_dir"
    printf '%s\n' "$failure_message" >"$artifact_dir/failure.txt"
    log "Scenario failed: $scenario_name"
    TESTS_LAST_SCENARIO_RESULT="$scenario_name|$failure_message"
    return 1
  fi

  if [ "$expectation" = "fail" ] && [ "$has_error" = "false" ]; then
    failure_message="expected fail but succeeded"
    rm -rf "$work_dir"
    printf '%s\n' "$failure_message" >"$artifact_dir/failure.txt"
    log "Scenario failed: $scenario_name"
    TESTS_LAST_SCENARIO_RESULT="$scenario_name|$failure_message"
    return 1
  fi

  if [ "$cleanup_failed" = "true" ]; then
    rm -rf "$work_dir"
    printf '%s\n' "$cleanup_failure_message" >"$artifact_dir/failure.txt"
    log "Scenario failed: $scenario_name"
    TESTS_LAST_SCENARIO_RESULT="$scenario_name|$cleanup_failure_message"
    return 1
  fi

  log "Scenario completed: $scenario_name"
  cleanup_artifact_dir_on_success "$artifact_dir"
  rm -rf "$work_dir"
  return 0
}

run_scenario_suite() {
  ensure_artifacts_dir
  require_command terraform
  require_command rsync

  run_preflight_checks

  local selector="${1:-}"
  local ran_any="false"
  local failures=()
  local scenario_dir
  while IFS= read -r scenario_dir; do
    [ -n "$scenario_dir" ] || continue
    ran_any="true"
    if ! run_single_scenario "$scenario_dir"; then
      failures+=("${TESTS_LAST_SCENARIO_RESULT:-${scenario_dir#"$TESTS_DIR/scenarios/"}|unknown failure}")
    fi
  done < <(resolve_scenarios "$selector")

  if [ "$ran_any" != "true" ]; then
    die "No scenarios were executed"
  fi

  if [ "${#failures[@]}" -gt 0 ]; then
    printf '[tests] Scenario failures summary:\n' >&2
    local failure
    for failure in "${failures[@]}"; do
      printf '[tests]   - %s\n' "$failure" >&2
    done
    exit 1
  fi

  log "Scenario suite completed."
}
