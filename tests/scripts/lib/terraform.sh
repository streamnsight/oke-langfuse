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

scenario_cleanup_policy() {
  local scenario_dir="$1"
  local cleanup_policy=""

  if scenario_has_manifest "$scenario_dir"; then
    cleanup_policy="$(scenario_json_get_string "$scenario_dir" '.cleanup_policy')" || cleanup_policy=""
    if [ -n "$cleanup_policy" ]; then
      case "$cleanup_policy" in
        always|success|never)
          printf '%s\n' "$cleanup_policy"
          return
          ;;
        *)
          die "Unsupported cleanup_policy '$cleanup_policy' for $scenario_dir"
          ;;
      esac
    fi
  fi

  if scenario_has_manifest "$scenario_dir" && [ "$(scenario_json_get_bool "$scenario_dir" '.destroy_after_run')" = "true" ]; then
    printf 'always\n'
  else
    printf 'never\n'
  fi
}

cleanup_policy_requires_destroy() {
  local cleanup_policy="$1"
  local scenario_succeeded="$2"

  case "$cleanup_policy" in
    always)
      return 0
      ;;
    success)
      [ "$scenario_succeeded" = "true" ]
      return
      ;;
    never)
      return 1
      ;;
    *)
      die "Unknown cleanup policy: $cleanup_policy"
      ;;
  esac
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

scenario_infra_bootstrap_lines() {
  local scenario_dir="$1"

  if scenario_has_manifest "$scenario_dir"; then
    scenario_json_get_raw "$scenario_dir" '
      .infra.bootstrap // [] |
      .[] |
      [
        (.target // ""),
        (.action // ""),
        (if has("size") then (.size | tostring) else "" end),
        (if has("use_custom_cloud_init") then (.use_custom_cloud_init | tostring) else "" end),
        (if has("is_public_endpoint") then (.is_public_endpoint | tostring) else "" end)
      ] | @tsv
    '
    return
  fi

  [ -f "$scenario_dir/fixture.env" ] || return 0

  (
    unset TARGET ACTION SIZE USE_CUSTOM_CLOUD_INIT IS_PUBLIC_ENDPOINT
    # shellcheck disable=SC1090
    source "$scenario_dir/fixture.env"
    require_non_empty "${TARGET:-}" "TARGET is required in $scenario_dir/fixture.env"
    require_non_empty "${ACTION:-}" "ACTION is required in $scenario_dir/fixture.env"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "${TARGET:-}" \
      "${ACTION:-}" \
      "${SIZE:-}" \
      "${USE_CUSTOM_CLOUD_INIT:-}" \
      "${IS_PUBLIC_ENDPOINT:-}"
  )
}

scenario_infra_bootstrap_signature() {
  local scenario_dir="$1"
  local bootstrap_lines
  bootstrap_lines="$(scenario_infra_bootstrap_lines "$scenario_dir")"

  if [ -n "$bootstrap_lines" ]; then
    printf '%s\n' "$bootstrap_lines"
  fi
}

scenario_infra_profile() {
  local scenario_dir="$1"
  local profile=""

  if scenario_has_manifest "$scenario_dir"; then
    profile="$(scenario_json_get_string "$scenario_dir" '.infra.profile')" || profile=""
    if [ -n "$profile" ]; then
      printf '%s\n' "$profile"
      return
    fi
  fi

  local signature
  signature="$(scenario_infra_bootstrap_signature "$scenario_dir")"
  if [ -n "$signature" ]; then
    printf 'fallback-%s\n' "$(slugify "$signature")"
  fi
}

scenario_infra_sort_key() {
  local scenario_dir="$1"
  local bootstrap_lines
  bootstrap_lines="$(scenario_infra_bootstrap_signature "$scenario_dir")"

  if [ -z "$bootstrap_lines" ]; then
    printf '90-000-000-000\n'
    return
  fi

  local desired_network="false"
  local desired_basic="false"
  local desired_enhanced="false"
  local enhanced_size="999"
  local enhanced_cloud_init="true"
  local enhanced_public_endpoint="false"

  while IFS=$'\t' read -r target action size use_custom_cloud_init is_public_endpoint; do
    [ -n "$target" ] || continue
    [ -n "$action" ] || die "ACTION is required for scenario infra bootstrap in $scenario_dir"

    case "$target" in
      network)
        desired_network="true"
        ;;
      basic)
        desired_basic="true"
        ;;
      enhanced)
        desired_enhanced="true"
        enhanced_size="${size:-2}"
        enhanced_cloud_init="${use_custom_cloud_init:-true}"
        enhanced_public_endpoint="${is_public_endpoint:-false}"
        ;;
      *)
        die "Unsupported fixture target '$target' in scenario infra bootstrap for $scenario_dir"
        ;;
    esac
  done <<<"$bootstrap_lines"

  if [ "$desired_enhanced" = "true" ]; then
    local public_rank cloud_init_rank
    if [ "$enhanced_public_endpoint" = "true" ]; then
      public_rank="1"
    else
      public_rank="0"
    fi

    if [ "$enhanced_cloud_init" = "true" ]; then
      cloud_init_rank="1"
    else
      cloud_init_rank="0"
    fi

    printf '20-%s%s-%03d-000\n' "$public_rank" "$cloud_init_rank" "$enhanced_size"
    return
  fi

  if [ "$desired_basic" = "true" ]; then
    printf '10-000-000-000\n'
    return
  fi

  if [ "$desired_network" = "true" ]; then
    printf '00-000-000-000\n'
    return
  fi

  printf '90-000-000-000\n'
}

record_touched_fixture_targets() {
  local touched_file="$1"
  local scenario_dir="$2"
  local bootstrap_lines
  bootstrap_lines="$(scenario_infra_bootstrap_signature "$scenario_dir")"
  [ -n "$bootstrap_lines" ] || return 0

  while IFS=$'\t' read -r target _action _size _use_custom_cloud_init _is_public_endpoint; do
    [ -n "$target" ] || continue
    if ! grep -Fxq "$target" "$touched_file" 2>/dev/null; then
      printf '%s\n' "$target" >>"$touched_file"
    fi
  done <<<"$bootstrap_lines"
}

cleanup_touched_fixture_targets() {
  local touched_file="$1"
  local cleanup_mode="${LIVE_FIXTURE_FINAL_CLEANUP:-never}"

  case "$cleanup_mode" in
    never)
      return 0
      ;;
    success)
      ;;
    *)
      die "Unsupported LIVE_FIXTURE_FINAL_CLEANUP value: $cleanup_mode"
      ;;
  esac

  [ -f "$touched_file" ] || return 0

  local target
  for target in enhanced basic network; do
    if grep -Fxq "$target" "$touched_file" 2>/dev/null; then
      destroy_fixture_if_present "$target"
    fi
  done
}

scenario_bootstrap_request_for_target() {
  local scenario_dir="$1"
  local requested_target="$2"
  local bootstrap_lines
  bootstrap_lines="$(scenario_infra_bootstrap_lines "$scenario_dir")"
  [ -n "$bootstrap_lines" ] || return 1

  local target action size use_custom_cloud_init is_public_endpoint
  while IFS=$'\t' read -r target action size use_custom_cloud_init is_public_endpoint; do
    [ -n "$target" ] || continue
    if [ "$target" = "$requested_target" ]; then
      printf '%s\t%s\t%s\t%s\t%s\n' \
        "$target" \
        "$action" \
        "$size" \
        "$use_custom_cloud_init" \
        "$is_public_endpoint"
      return 0
    fi
  done <<<"$bootstrap_lines"

  return 1
}

run_fixture_request_line() {
  local request_line="$1"
  local target action size use_custom_cloud_init is_public_endpoint

  IFS=$'\t' read -r target action size use_custom_cloud_init is_public_endpoint <<<"$request_line"
  [ -n "$target" ] || die "Fixture request line is missing TARGET."
  [ -n "$action" ] || die "Fixture request line is missing ACTION for target '$target'."

  run_fixture_action_with_overrides \
    "$target" \
    "$action" \
    "$size" \
    "$use_custom_cloud_init" \
    "$is_public_endpoint"
}

activate_scenario_infra_profile() {
  local scenario_dir="$1"
  local touched_file="${2:-}"
  local bootstrap_lines
  local profile
  bootstrap_lines="$(scenario_infra_bootstrap_signature "$scenario_dir")"
  [ -n "$bootstrap_lines" ] || return 0
  profile="$(scenario_infra_profile "$scenario_dir")"

  local line_count="0"

  while IFS=$'\t' read -r target action _size _use_custom_cloud_init _is_public_endpoint; do
    [ -n "$target" ] || continue
    [ -n "$action" ] || die "ACTION is required for scenario infra bootstrap in $scenario_dir"
    line_count=$((line_count + 1))

    case "$target" in
      network|basic|enhanced)
        ;;
      *)
        die "Unsupported fixture target '$target' in scenario infra bootstrap for $scenario_dir"
        ;;
    esac
  done <<<"$bootstrap_lines"

  if [ "$line_count" -eq 0 ]; then
    return 0
  fi

  if [ -n "$profile" ]; then
    log "Activating live infra profile '$profile' for ${scenario_dir#"$TESTS_DIR/scenarios/"}"
  fi

  if [ -n "$touched_file" ]; then
    record_touched_fixture_targets "$touched_file" "$scenario_dir"
  fi

  while IFS=$'\t' read -r target action size use_custom_cloud_init is_public_endpoint; do
    [ -n "$target" ] || continue

    if [ "$action" = "up" ] && fixture_state_exists_for_target "$target"; then
      case "$target" in
        enhanced)
          local requested_size requested_cloud_init requested_public_endpoint
          local transition_kind
          requested_size="${size:-2}"
          requested_cloud_init="${use_custom_cloud_init:-true}"
          requested_public_endpoint="${is_public_endpoint:-false}"
          transition_kind="$(
            enhanced_fixture_transition_kind \
              "$requested_size" \
              "$requested_cloud_init" \
              "$requested_public_endpoint"
          )"
          case "$transition_kind" in
            noop)
              ;;
            create)
              log "Enhanced fixture is absent or incomplete; bootstrapping cluster and node pool."
              ;;
            nodepool-create)
              log "Enhanced cluster is already present but the node pool is missing; creating the node pool without rebuilding the cluster."
              ;;
            cluster-create)
              log "Enhanced node pool state exists without a matching cluster; rebuilding the cluster layer before reconciling the node pool."
              ;;
            nodepool-update)
              log "Enhanced node pool differs from requested profile; reconciling node-pool settings in place and letting OCI cycle nodes."
              ;;
            cluster-update)
              log "Enhanced cluster endpoint differs from requested profile; reconciling cluster settings in place while reusing the node pool."
              ;;
            cluster-and-nodepool-update)
              log "Enhanced cluster and node pool both differ from requested profile; reconciling in place and avoiding a fixture teardown."
              ;;
            *)
              die "Unknown enhanced fixture transition kind: $transition_kind"
              ;;
          esac
          ;;
        basic|network)
          ;;
      esac
    fi

    run_fixture_request_line "$(printf '%s\t%s\t%s\t%s\t%s' \
      "$target" \
      "$action" \
      "$size" \
      "$use_custom_cloud_init" \
      "$is_public_endpoint")"
  done <<<"$bootstrap_lines"
}

prewarm_live_fixture_suite() {
  if [ "${SUITE:-live}" != "live" ]; then
    die "fixture-prewarm only supports SUITE=live."
  fi
  if [ -n "${SCENARIO:-}" ]; then
    die "fixture-prewarm does not accept SCENARIO; it prewarms the ordered live suite."
  fi

  ensure_artifacts_dir

  local ordered_scenarios
  ordered_scenarios="$(plan_scenario_execution_order "")"

  local first_network_request=""
  local first_basic_request=""
  local first_enhanced_request=""
  local scenario_dir=""

  while IFS= read -r scenario_dir; do
    [ -n "$scenario_dir" ] || continue

    if [ -z "$first_network_request" ]; then
      first_network_request="$(scenario_bootstrap_request_for_target "$scenario_dir" network || true)"
    fi
    if [ -z "$first_basic_request" ]; then
      first_basic_request="$(scenario_bootstrap_request_for_target "$scenario_dir" basic || true)"
    fi
    if [ -z "$first_enhanced_request" ]; then
      first_enhanced_request="$(scenario_bootstrap_request_for_target "$scenario_dir" enhanced || true)"
    fi
  done <<<"$ordered_scenarios"

  [ -n "$first_network_request" ] || die "The live suite does not declare a network bootstrap step to prewarm."

  log "Prewarming live suite fixtures from the ordered live scenario plan."
  log "Preparing shared network first."
  run_fixture_request_line "$first_network_request"

  local pids=()
  local labels=()
  local failures=()

  if [ -n "$first_basic_request" ]; then
    log "Prewarming first basic profile."
    (
      run_fixture_request_line "$first_basic_request"
    ) &
    pids+=("$!")
    labels+=("basic")
  fi

  if [ -n "$first_enhanced_request" ]; then
    log "Prewarming first enhanced profile."
    (
      run_fixture_request_line "$first_enhanced_request"
    ) &
    pids+=("$!")
    labels+=("enhanced")
  fi

  local i
  for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
      failures+=("${labels[$i]}")
    fi
  done

  if [ "${#failures[@]}" -gt 0 ]; then
    die "fixture-prewarm failed for target(s): ${failures[*]}"
  fi

  log "Live fixture prewarm completed. Warm fixtures remain available for a subsequent SUITE=live run."
}

plan_scenario_execution_order() {
  local selector="${1:-}"
  local scenario_dirs
  scenario_dirs="$(resolve_scenarios "$selector")"

  if [ "${SUITE:-}" != "live" ] || [ -n "$selector" ]; then
    printf '%s\n' "$scenario_dirs"
    return
  fi

  local temp_dir
  temp_dir="$(mktemp -d)"
  local -a group_profiles=()
  local -a group_files=()
  local -a group_sort_keys=()
  local scenario_dir

  while IFS= read -r scenario_dir; do
    [ -n "$scenario_dir" ] || continue

    local profile signature group_index
    profile="$(scenario_infra_profile "$scenario_dir")"
    signature="$(scenario_infra_bootstrap_signature "$scenario_dir")"
    group_index="-1"

    if [ -z "$profile" ]; then
      profile="__ungrouped__:${scenario_dir#"$TESTS_DIR/scenarios/"}"
    fi

    local i
    for i in "${!group_profiles[@]}"; do
      if [ "${group_profiles[$i]}" = "$profile" ]; then
        group_index="$i"
        break
      fi
    done

    if [ "$group_index" -lt 0 ]; then
      group_profiles+=("$profile")
      group_files+=("$temp_dir/group-${#group_profiles[@]}.txt")
      group_sort_keys+=("$(scenario_infra_sort_key "$scenario_dir")")
      group_index=$((${#group_profiles[@]} - 1))
      : >"${group_files[$group_index]}"
    else
      local first_scenario existing_signature
      first_scenario="$(head -n 1 "${group_files[$group_index]}")"
      existing_signature="$(scenario_infra_bootstrap_signature "$first_scenario")"
      if [ "$existing_signature" != "$signature" ]; then
        rm -rf "$temp_dir"
        die "Scenario profile '$profile' maps to inconsistent bootstrap definitions."
      fi
    fi

    printf '%s\n' "$scenario_dir" >>"${group_files[$group_index]}"
  done <<<"$scenario_dirs"

  local ordered_groups_file
  ordered_groups_file="$temp_dir/ordered-groups.txt"
  : >"$ordered_groups_file"

  local i
  for i in "${!group_files[@]}"; do
    printf '%s\t%04d\t%s\n' \
      "${group_sort_keys[$i]}" \
      "$i" \
      "${group_files[$i]}" >>"$ordered_groups_file"
  done

  while IFS=$'\t' read -r _sort_key _group_index group_file; do
    cat "$group_file"
  done < <(sort "$ordered_groups_file")

  rm -rf "$temp_dir"
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

prefix_report_lines() {
  sed 's/^/[tests]   /'
}

tail_text_lines() {
  local text="${1:-}"
  local max_lines="${2:-40}"
  [ -n "$text" ] || return 0
  printf '%s\n' "$text" | tail -n "$max_lines"
}

log_file_excerpt() {
  local log_file="$1"
  local max_lines="${2:-40}"
  [ -s "$log_file" ] || return 0
  tail -n "$max_lines" "$log_file"
}

print_failure_report_block() {
  local label="$1"
  local value="${2:-}"
  [ -n "$value" ] || return 0
  printf '[tests] %s:\n' "$label"
  printf '%s\n' "$value" | prefix_report_lines
}

write_failure_report() {
  local outfile="$1"
  local scenario_name="$2"
  local summary="$3"
  local artifact_dir="$4"
  local relevant_log="${5:-}"
  local assertion_type="${6:-}"
  local expected_label="${7:-}"
  local expected_value="${8:-}"
  local actual_label="${9:-}"
  local actual_value="${10:-}"
  local excerpt=""

  excerpt="$(log_file_excerpt "$relevant_log" 40)"

  {
    printf '[tests] Scenario failed: %s\n' "$scenario_name"
    printf '[tests] Summary: %s\n' "$summary"
    printf '[tests] Artifacts: %s\n' "$artifact_dir"
    if [ -n "$relevant_log" ]; then
      printf '[tests] Relevant log: %s\n' "$relevant_log"
    fi
    print_failure_report_block "Assertion" "$assertion_type"
    print_failure_report_block "$expected_label" "$expected_value"
    print_failure_report_block "$actual_label" "$actual_value"
    print_failure_report_block "Relevant log excerpt (last 40 lines)" "$excerpt"
  } >"$outfile"
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

prepare_scenario_infra() {
  local scenario_dir="$1"
  activate_scenario_infra_profile "$scenario_dir"
}

prepare_scenario_workdir() {
  local scenario_dir="$1"
  local scenario_name="$2"
  local work_dir="$3"
  local artifact_dir="${4:-}"

  if [ -f "$scenario_dir/prepare.sh" ]; then
    TESTS_SCENARIO_ARTIFACT_DIR="$artifact_dir" \
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
  local mode raw_mode cleanup_policy
  raw_mode="$(scenario_mode "$scenario_dir")"
  mode="$raw_mode"
  cleanup_policy="$(scenario_cleanup_policy "$scenario_dir")"
  if [[ "$mode" == *-destroy ]]; then
    cleanup_policy="always"
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
  local failure_summary=""
  local failure_assertion_type=""
  local failure_expected_label=""
  local failure_expected_value=""
  local failure_actual_label=""
  local failure_actual_value=""
  local failure_log_path=""
  local failure_report_file="$artifact_dir/failure.txt"
  local cleanup_failed="false"
  local destroy_args=(-input=false -lock=false -no-color -var-file="terraform.tfvars")

  log "Running scenario $scenario_name (expect: $expectation, mode: $raw_mode, cleanup: $cleanup_policy)"
  if [ "${TESTS_SKIP_SCENARIO_BOOTSTRAP:-false}" != "true" ]; then
    prepare_scenario_infra "$scenario_dir"
  fi
  copy_repo_for_scenario "$work_dir"
  prepare_scenario_workdir "$scenario_dir" "$scenario_name" "$work_dir" "$artifact_dir"

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
    end_log_group
    failure_summary="terraform init failed"
    failure_log_path="$init_log"
    failure_actual_label="Actual result"
    failure_actual_value="Terraform init exited non-zero. See the relevant log excerpt below for the captured output."
    rm -rf "$work_dir"
    write_failure_report \
      "$failure_report_file" \
      "$scenario_name" \
      "$failure_summary" \
      "$artifact_dir" \
      "$failure_log_path" \
      "" \
      "" \
      "" \
      "$failure_actual_label" \
      "$failure_actual_value"
    cat "$failure_report_file" >&2
    TESTS_LAST_SCENARIO_RESULT="$scenario_name|$failure_summary|$artifact_dir"
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
        TESTS_SCENARIO_ARTIFACT_DIR="$artifact_dir" \
          TESTS_SCENARIO_NAME="$scenario_name" \
          bash "$work_dir/tests/scenarios/$scenario_name/run.sh" "$work_dir" 2>&1 | tee "$run_log"
        local script_status=${PIPESTATUS[0]}
        set -e
      else
        set +e
        TESTS_SCENARIO_ARTIFACT_DIR="$artifact_dir" \
          TESTS_SCENARIO_NAME="$scenario_name" \
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

  if [ -n "$expected_output" ] && [ "$has_error" = "false" ]; then
    local normalized_output normalized_expected_output
    normalized_output="$(printf '%s\n' "$command_output" | normalize_whitespace)"
    normalized_expected_output="$(printf '%s\n' "$expected_output" | normalize_whitespace)"
    if [[ "$normalized_output" != *"$normalized_expected_output"* ]]; then
      failure_summary="output did not contain expected text"
      failure_assertion_type="expected output substring"
      failure_expected_label="Expected output"
      failure_expected_value="$expected_output"
      failure_actual_label="Actual output"
      failure_actual_value="$command_output"
      failure_log_path="$run_log"
    fi
  fi

  if [ -z "$failure_summary" ] && [ -n "$expected_error" ] && [ "$has_error" = "true" ]; then
    local normalized_output normalized_expected
    normalized_output="$(printf '%s\n' "$command_output" | normalize_whitespace)"
    normalized_expected="$(printf '%s\n' "$expected_error" | normalize_whitespace)"
    if [[ "$normalized_output" != *"$normalized_expected"* ]]; then
      failure_summary="failed, but not with the expected error text"
      failure_assertion_type="expected error substring"
      failure_expected_label="Expected error"
      failure_expected_value="$expected_error"
      failure_actual_label="Actual output"
      failure_actual_value="$(tail_text_lines "$command_output" 40)"
      failure_log_path="$run_log"
    fi
  fi

  if [ -z "$failure_summary" ] && [ "$expectation" = "pass" ] && [ "$has_error" = "true" ]; then
    failure_summary="expected pass but failed.$(terraform_provider_runtime_hint "$run_log")"
    failure_assertion_type="scenario expectation"
    failure_expected_label="Expected outcome"
    failure_expected_value="pass"
    failure_actual_label="Actual result"
    failure_actual_value="$(printf 'Outcome: fail\nCaptured output (last 40 lines):\n%s\n' "$(tail_text_lines "$command_output" 40)")"
    failure_log_path="$run_log"
  fi

  if [ -z "$failure_summary" ] && [ "$expectation" = "fail" ] && [ "$has_error" = "false" ]; then
    failure_summary="expected fail but succeeded"
    failure_assertion_type="scenario expectation"
    failure_expected_label="Expected outcome"
    failure_expected_value="fail"
    failure_actual_label="Actual result"
    failure_actual_value="$(printf 'Outcome: pass\nCaptured output (last 40 lines):\n%s\n' "$(tail_text_lines "$command_output" 40)")"
    failure_log_path="$run_log"
  fi

  local scenario_succeeded="true"
  if [ -n "$failure_summary" ]; then
    scenario_succeeded="false"
  fi

  if cleanup_policy_requires_destroy "$cleanup_policy" "$scenario_succeeded" && [ -f "$work_dir/terraform.tfstate" ]; then
    begin_log_group "Scenario $scenario_name: terraform destroy"
    if ! run_logged_command "$destroy_log" terraform -chdir="$work_dir" destroy "${destroy_args[@]}" -auto-approve; then
      cleanup_failed="true"
    fi
    end_log_group
  fi

  if [ "$cleanup_failed" = "true" ]; then
    failure_summary="terraform destroy failed after scenario execution"
    failure_assertion_type=""
    failure_expected_label=""
    failure_expected_value=""
    failure_actual_label="Actual result"
    failure_actual_value="Terraform destroy exited non-zero during scenario cleanup. See the relevant log excerpt below for the captured output."
    failure_log_path="$destroy_log"
    scenario_succeeded="false"
  fi

  if [ "$scenario_succeeded" != "true" ]; then
    write_failure_report \
      "$failure_report_file" \
      "$scenario_name" \
      "$failure_summary" \
      "$artifact_dir" \
      "$failure_log_path" \
      "$failure_assertion_type" \
      "$failure_expected_label" \
      "$failure_expected_value" \
      "$failure_actual_label" \
      "$failure_actual_value"
    cat "$failure_report_file" >&2
    rm -rf "$work_dir"
    TESTS_LAST_SCENARIO_RESULT="$scenario_name|$failure_summary|$artifact_dir"
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
  local ordered_scenarios
  local active_profile=""
  local touched_targets_file
  touched_targets_file="$(mktemp)"
  ordered_scenarios="$(plan_scenario_execution_order "$selector")"
  local scenario_dir
  while IFS= read -r scenario_dir; do
    [ -n "$scenario_dir" ] || continue
    ran_any="true"

    if [ "${SUITE:-}" = "live" ]; then
      if [ -n "$selector" ]; then
        activate_scenario_infra_profile "$scenario_dir" "$touched_targets_file"
      else
        local scenario_profile
        scenario_profile="$(scenario_infra_profile "$scenario_dir")"
        if [ "$scenario_profile" != "$active_profile" ]; then
          activate_scenario_infra_profile "$scenario_dir" "$touched_targets_file"
          active_profile="$scenario_profile"
        fi
      fi
      TESTS_SKIP_SCENARIO_BOOTSTRAP="true"
    fi

    if ! run_single_scenario "$scenario_dir"; then
      failures+=("${TESTS_LAST_SCENARIO_RESULT:-${scenario_dir#"$TESTS_DIR/scenarios/"}|unknown failure}")
    fi

    unset TESTS_SKIP_SCENARIO_BOOTSTRAP
  done <<<"$ordered_scenarios"

  if [ "$ran_any" != "true" ]; then
    rm -f "$touched_targets_file"
    die "No scenarios were executed"
  fi

  if [ "${#failures[@]}" -gt 0 ]; then
    rm -f "$touched_targets_file"
    printf '[tests] Scenario failures summary:\n' >&2
    local failure
    for failure in "${failures[@]}"; do
      IFS='|' read -r failure_scenario failure_reason failure_artifact_dir <<<"$failure"
      if [ -n "${failure_artifact_dir:-}" ]; then
        printf '[tests]   - %s: %s (artifacts: %s)\n' "$failure_scenario" "$failure_reason" "$failure_artifact_dir" >&2
      else
        printf '[tests]   - %s\n' "$failure" >&2
      fi
    done
    exit 1
  fi

  if [ "${SUITE:-}" = "live" ] && [ "${LIVE_FIXTURE_FINAL_CLEANUP:-never}" = "success" ]; then
    cleanup_touched_fixture_targets "$touched_targets_file"
  fi

  rm -f "$touched_targets_file"

  log "Scenario suite completed."
}
