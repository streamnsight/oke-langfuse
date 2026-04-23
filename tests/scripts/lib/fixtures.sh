#!/usr/bin/env bash

fixture_dir_for_target() {
  case "$1" in
    network)
      printf '%s\n' "$TESTS_DIR/fixtures/network"
      ;;
    basic)
      printf '%s\n' "$TESTS_DIR/fixtures/cluster-basic"
      ;;
    enhanced)
      printf '%s\n' "$TESTS_DIR/fixtures/cluster-enhanced"
      ;;
    *)
      die "Unknown fixture target: $1"
      ;;
  esac
}

fixture_state_exists() {
  local fixture_dir="$1"
  local state_file="$fixture_dir/terraform.tfstate"
  [ -f "$state_file" ] || return 1

  jq -e 'any(.resources[]?; .mode == "managed" and ((.instances // []) | length > 0))' "$state_file" >/dev/null 2>&1
}

fixture_state_exists_for_target() {
  local fixture_dir
  fixture_dir="$(fixture_dir_for_target "$1")"
  fixture_state_exists "$fixture_dir"
}

fixture_state_file_for_target() {
  local fixture_dir
  fixture_dir="$(fixture_dir_for_target "$1")"
  printf '%s/terraform.tfstate\n' "$fixture_dir"
}

fixture_state_output_value() {
  local target="$1"
  local output_name="$2"
  local state_file
  state_file="$(fixture_state_file_for_target "$target")"

  [ -f "$state_file" ] || return 1

  jq -r --arg name "$output_name" '
    try .outputs[$name].value | if . == null then "" else tostring end
  ' "$state_file"
}

fixture_matches_requested_state() {
  local target="$1"
  local requested_size="${2:-}"
  local requested_cloud_init="${3:-}"
  local requested_public_endpoint="${4:-}"

  if ! fixture_state_exists_for_target "$target"; then
    return 1
  fi

  case "$target" in
    network|basic)
      return 0
      ;;
    enhanced)
      local actual_size actual_cloud_init actual_public_endpoint
      actual_size="$(fixture_state_output_value "$target" node_pool_size 2>/dev/null || true)"
      actual_cloud_init="$(fixture_state_output_value "$target" use_custom_cloud_init 2>/dev/null || true)"
      actual_public_endpoint="$(fixture_state_output_value "$target" is_public_endpoint 2>/dev/null || true)"

      [ -n "$actual_size" ] || return 1
      [ -n "$actual_cloud_init" ] || return 1
      [ -n "$actual_public_endpoint" ] || return 1

      [ "$actual_size" = "$requested_size" ] || return 1
      [ "$actual_cloud_init" = "$requested_cloud_init" ] || return 1
      [ "$actual_public_endpoint" = "$requested_public_endpoint" ] || return 1
      return 0
      ;;
    *)
      die "Unknown fixture target: $target"
      ;;
  esac
}

run_fixture_action_with_overrides() {
  local target="$1"
  local action="$2"
  local size="${3:-}"
  local use_custom_cloud_init="${4:-}"
  local is_public_endpoint="${5:-}"

  (
    if [ -n "$use_custom_cloud_init" ]; then
      export USE_CUSTOM_CLOUD_INIT="$use_custom_cloud_init"
    else
      unset USE_CUSTOM_CLOUD_INIT
    fi

    if [ -n "$is_public_endpoint" ]; then
      export IS_PUBLIC_ENDPOINT="$is_public_endpoint"
    else
      unset IS_PUBLIC_ENDPOINT
    fi

    run_fixture_action "$target" "$action" "$size"
  )
}

destroy_fixture_if_present() {
  local target="$1"

  if fixture_state_exists_for_target "$target"; then
    run_fixture_action "$target" down
  fi
}

assert_network_destroy_is_safe() {
  local basic_dir enhanced_dir
  require_command jq
  basic_dir="$(fixture_dir_for_target basic)"
  enhanced_dir="$(fixture_dir_for_target enhanced)"
  if fixture_state_exists "$basic_dir" || fixture_state_exists "$enhanced_dir"; then
    die "Cannot destroy or refresh the shared network while cluster fixtures still have state."
  fi
}

assert_network_fixture_ready() {
  local network_dir
  network_dir="$(fixture_dir_for_target network)"
  if [ ! -f "$network_dir/terraform.tfstate" ]; then
    die "The shared network fixture must be applied before managing cluster fixtures."
  fi
}

assert_fixture_config_exists() {
  local fixture_dir="$1"
  if ! find "$fixture_dir" -maxdepth 1 -type f -name '*.tf' | grep -q .; then
    die "Fixture workspace is scaffolded but has no Terraform files yet: $fixture_dir"
  fi
}

fixture_has_config() {
  local fixture_dir="$1"
  find "$fixture_dir" -maxdepth 1 -type f -name '*.tf' | grep -q .
}

fixture_required_env_vars() {
  case "$1" in
    network)
      printf '%s\n' OCI_PROFILE TF_VAR_region TF_VAR_tenancy_ocid TF_VAR_compartment_id
      ;;
    basic)
      printf '%s\n' OCI_PROFILE TF_VAR_region TF_VAR_tenancy_ocid TF_VAR_cluster_compartment_id
      ;;
    enhanced)
      printf '%s\n' OCI_PROFILE TF_VAR_region TF_VAR_tenancy_ocid TF_VAR_cluster_compartment_id
      ;;
    *)
      die "Unknown fixture target: $1"
      ;;
  esac
}

assert_fixture_env_ready() {
  local target="$1"
  local missing=()
  local name

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ -z "${!name:-}" ]; then
      missing+=("$name")
    fi
  done < <(fixture_required_env_vars "$target")

  if [ "${#missing[@]}" -gt 0 ]; then
    printf '[tests] Missing required environment variables for fixture target %s:\n' "$target" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    die "Populate tests/.env or export the required variables before running fixture actions."
  fi
}

fixture_capture_outputs() {
  local fixture_dir="$1"
  local output_file="$2"

  if terraform -chdir="$fixture_dir" output -json >"$output_file" 2>"$output_file.stderr"; then
    return 0
  fi

  printf '{}\n' >"$output_file"
  return 1
}

fixture_oci_capture() {
  local stdout_file="$1"
  local stderr_file="$2"
  shift 2

  local oci_args=()
  while IFS= read -r arg; do
    [ -n "$arg" ] && oci_args+=("$arg")
  done < <(oci_cli_global_args)

  oci "${oci_args[@]}" "$@" >"$stdout_file" 2>"$stderr_file"
}

enhanced_fixture_cluster_public_value() {
  local cluster_file="$1"

  if [ ! -f "$cluster_file" ]; then
    printf 'unknown\n'
    return
  fi

  jq -r '
    try (
      if (.data | type) != "object" then
        null
      elif (.data | has("endpoint-config")) and ((.data["endpoint-config"] | type) == "object") and (.data["endpoint-config"] | has("is-public-ip-enabled")) then
        .data["endpoint-config"]["is-public-ip-enabled"]
      elif (.data.endpointConfig? | type) == "object" and (.data.endpointConfig | has("isPublicIpEnabled")) then
        .data.endpointConfig.isPublicIpEnabled
      elif (.data.endpoint_config? | type) == "object" and (.data.endpoint_config | has("is_public_ip_enabled")) then
        .data.endpoint_config.is_public_ip_enabled
      else
        null
      end
    ) | if . == null then "unknown" else tostring end
  ' "$cluster_file" 2>/dev/null || printf 'unknown\n'
}

enhanced_fixture_requested_output_bool() {
  local outputs_file="$1"
  local output_name="$2"

  if [ ! -f "$outputs_file" ]; then
    printf 'unknown\n'
    return
  fi

  jq -r --arg name "$output_name" '
    try .[$name].value | if . == null then "unknown" else tostring end
  ' "$outputs_file" 2>/dev/null || printf 'unknown\n'
}

enhanced_fixture_cloud_init_node_pool_count() {
  local node_pools_file="$1"
  local outputs_file="${2:-}"
  local node_pool_count="${3:-0}"

  if [ -f "$node_pools_file" ]; then
    local metadata_available metadata_count
    metadata_available="$(jq -r '
      any(
        try (.data // [])[];
        has("node-metadata") or has("nodeMetadata") or has("node_metadata")
      )
    ' "$node_pools_file" 2>/dev/null || printf 'false\n')"

    if [ "$metadata_available" = "true" ]; then
      metadata_count="$(jq -r '
        [
          try (.data // [])[] |
          select(
            (
              (
                ."node-metadata"."user_data"
                // .nodeMetadata.user_data
                // .nodeMetadata.userData
                // .node_metadata.user_data
                // ""
              ) | tostring | length
            ) > 0
          )
        ] | length
      ' "$node_pools_file" 2>/dev/null || printf '0\n')"
      printf '%s\n' "$metadata_count"
      return
    fi
  fi

  if [ -f "$outputs_file" ]; then
    local requested_cloud_init
    requested_cloud_init="$(enhanced_fixture_requested_output_bool "$outputs_file" use_custom_cloud_init)"
    if [ "$requested_cloud_init" = "true" ] && [ "$node_pool_count" -ge 1 ]; then
      printf '%s\n' "$node_pool_count"
      return
    fi
  fi

  printf '0\n'
}

enhanced_fixture_expected_size() {
  local requested_size="${1:-}"
  if [ -n "$requested_size" ]; then
    printf '%s\n' "$requested_size"
  else
    printf '2\n'
  fi
}

enhanced_fixture_expected_cloud_init() {
  if [ -n "${USE_CUSTOM_CLOUD_INIT:-}" ]; then
    printf '%s\n' "$USE_CUSTOM_CLOUD_INIT"
  else
    printf 'true\n'
  fi
}

enhanced_fixture_expected_public_endpoint() {
  if [ -n "${IS_PUBLIC_ENDPOINT:-}" ]; then
    printf '%s\n' "$IS_PUBLIC_ENDPOINT"
  else
    printf 'false\n'
  fi
}

enhanced_fixture_cluster_id() {
  local fixture_dir="$1"
  if [ ! -f "$fixture_dir/terraform.tfstate" ]; then
    return 0
  fi

  terraform -chdir="$fixture_dir" output -json 2>/dev/null \
    | jq -r 'try .cluster_id.value // empty'
}

enhanced_fixture_select_latest_work_request_id() {
  local nodepool_file="$1"
  local cluster_file="$2"
  local work_request_id=""

  if [ -f "$nodepool_file" ]; then
    work_request_id="$(jq -r 'try (.data[0].id // empty)' "$nodepool_file" 2>/dev/null || true)"
  fi

  if [ -z "$work_request_id" ] && [ -f "$cluster_file" ]; then
    work_request_id="$(jq -r 'try (.data[0].id // empty)' "$cluster_file" 2>/dev/null || true)"
  fi

  printf '%s\n' "$work_request_id"
}

enhanced_fixture_write_summary() {
  local summary_file="$1"
  local reason="$2"
  local cluster_id="$3"
  local expected_size="$4"
  local expected_public="$5"
  local expected_cloud_init="$6"
  local cluster_file="$7"
  local node_pools_file="$8"
  local selected_work_request_id="$9"
  local outputs_file="${10:-}"

  local cluster_state="unknown"
  local cluster_public="unknown"
  local node_pool_count="0"
  local active_node_pool_count="0"
  local max_node_pool_size="0"
  local cloud_init_node_pool_count="0"
  local selector_kubernetes_version="${TF_VAR_kubernetes_version:-v1.34.1}"
  local selector_operating_system="${TF_VAR_fixture_operating_system:-Oracle Linux}"
  local selector_operating_system_version="${TF_VAR_fixture_operating_system_version:-8}"
  local selector_shape="${TF_VAR_fixture_shape:-${TF_VAR_node_shape:-VM.Standard.E5.Flex}}"
  local selector_image_override="${TF_VAR_fixture_node_image_id:-}"
  local resolved_image_id="unknown"
  local resolved_image_name="unknown"
  local resolved_source_name="unknown"

  if [ -f "$cluster_file" ]; then
    cluster_state="$(jq -r '
      try (
        .data."lifecycle-state"
        // .data.lifecycleState
        // .data.lifecycle_state
        // .data.state
        // "unknown"
      )
    ' "$cluster_file" 2>/dev/null || printf 'unknown\n')"
    cluster_public="$(enhanced_fixture_cluster_public_value "$cluster_file")"
  fi

  if [ -f "$node_pools_file" ]; then
    node_pool_count="$(jq -r 'try (.data | length) // 0' "$node_pools_file" 2>/dev/null || printf '0\n')"
    active_node_pool_count="$(jq -r '
      [
        try (.data // [])[] |
        select(
          (
            ."lifecycle-state"
            // .lifecycleState
            // .lifecycle_state
            // .state
            // ""
          ) == "ACTIVE"
        )
      ] | length
    ' "$node_pools_file" 2>/dev/null || printf '0\n')"
    max_node_pool_size="$(jq -r '
      [
        try (.data // [])[] |
        (
          ."node-config-details".size
          // .nodeConfigDetails.size
          // .node_config_details.size
          // 0
        )
      ] | max // 0
    ' "$node_pools_file" 2>/dev/null || printf '0\n')"
  fi

  if [ -f "$outputs_file" ]; then
    local value

    value="$(jq -r 'try .node_image_selector.value.kubernetes_version // empty' "$outputs_file" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      selector_kubernetes_version="$value"
    fi

    value="$(jq -r 'try .node_image_selector.value.operating_system // empty' "$outputs_file" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      selector_operating_system="$value"
    fi

    value="$(jq -r 'try .node_image_selector.value.operating_system_version // empty' "$outputs_file" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      selector_operating_system_version="$value"
    fi

    value="$(jq -r 'try .node_image_selector.value.shape // empty' "$outputs_file" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      selector_shape="$value"
    fi

    value="$(jq -r 'try .node_image_selector.value.image_id_override // empty' "$outputs_file" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      selector_image_override="$value"
    fi

    value="$(jq -r 'try .node_pool_image_id.value // empty' "$outputs_file" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      resolved_image_id="$value"
    fi

    value="$(jq -r 'try .node_image_selector.value.selected_image_name // empty' "$outputs_file" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      resolved_image_name="$value"
    fi

    value="$(jq -r 'try .node_image_selector.value.selected_source_name // empty' "$outputs_file" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      resolved_source_name="$value"
    fi
  fi

  if [ "$cluster_public" = "unknown" ] && [ -f "$outputs_file" ]; then
    cluster_public="$(enhanced_fixture_requested_output_bool "$outputs_file" is_public_endpoint)"
  fi

  cloud_init_node_pool_count="$(enhanced_fixture_cloud_init_node_pool_count "$node_pools_file" "$outputs_file" "$node_pool_count")"

  {
    if [ -s "$summary_file" ]; then
      printf '\n'
    fi
    printf 'Enhanced Fixture Diagnostics\n'
    printf '============================\n'
    printf 'Reason: %s\n' "$reason"
    printf 'Cluster ID: %s\n' "${cluster_id:-unknown}"
    printf 'Expected node pool size: %s\n' "$expected_size"
    printf 'Expected public endpoint: %s\n' "$expected_public"
    printf 'Expected custom cloud-init: %s\n' "$expected_cloud_init"
    printf 'Selector Kubernetes version: %s\n' "$selector_kubernetes_version"
    printf 'Selector operating system: %s\n' "$selector_operating_system"
    printf 'Selector operating system version: %s\n' "$selector_operating_system_version"
    printf 'Selector shape: %s\n' "$selector_shape"
    printf 'Selector image override: %s\n' "${selector_image_override:-none}"
    printf 'Resolved image ID: %s\n' "$resolved_image_id"
    printf 'Resolved image name: %s\n' "$resolved_image_name"
    printf 'Resolved OKE source name: %s\n' "$resolved_source_name"
    printf 'Cluster state: %s\n' "$cluster_state"
    printf 'Cluster public endpoint: %s\n' "$cluster_public"
    printf 'Node pool count: %s\n' "$node_pool_count"
    printf 'Active node pool count: %s\n' "$active_node_pool_count"
    printf 'Max observed node pool size: %s\n' "$max_node_pool_size"
    printf 'Node pools with user_data: %s\n' "$cloud_init_node_pool_count"
    printf 'Selected work request ID: %s\n' "${selected_work_request_id:-none}"
  } >>"$summary_file"
}

enhanced_fixture_collect_diagnostics() {
  local fixture_dir="$1"
  local artifact_dir="$2"
  local reason="$3"
  local expected_size="$4"
  local expected_public="$5"
  local expected_cloud_init="$6"

  local cluster_file="$artifact_dir/live-cluster.json"
  local cluster_stderr="$artifact_dir/live-cluster.stderr"
  local node_pools_file="$artifact_dir/live-node-pools.json"
  local node_pools_stderr="$artifact_dir/live-node-pools.stderr"
  local nodepool_wr_file="$artifact_dir/oke-work-requests-nodepool.json"
  local nodepool_wr_stderr="$artifact_dir/oke-work-requests-nodepool.stderr"
  local cluster_wr_file="$artifact_dir/oke-work-requests-cluster.json"
  local cluster_wr_stderr="$artifact_dir/oke-work-requests-cluster.stderr"
  local work_request_file="$artifact_dir/oke-work-request.json"
  local work_request_stderr="$artifact_dir/oke-work-request.stderr"
  local work_request_errors_file="$artifact_dir/oke-work-request-errors.json"
  local work_request_errors_stderr="$artifact_dir/oke-work-request-errors.stderr"
  local summary_file="$artifact_dir/validator-summary.txt"
  local outputs_file="$artifact_dir/outputs.json"

  local cluster_id
  cluster_id="$(enhanced_fixture_cluster_id "$fixture_dir")"

  if [ -n "$cluster_id" ]; then
    fixture_oci_capture "$cluster_file" "$cluster_stderr" ce cluster get --cluster-id "$cluster_id" || true
    fixture_oci_capture "$node_pools_file" "$node_pools_stderr" \
      ce node-pool list \
      --compartment-id "$TF_VAR_cluster_compartment_id" \
      --cluster-id "$cluster_id" \
      --all || true
    fixture_oci_capture "$nodepool_wr_file" "$nodepool_wr_stderr" \
      ce work-request list \
      --compartment-id "$TF_VAR_cluster_compartment_id" \
      --cluster-id "$cluster_id" \
      --resource-type NODEPOOL \
      --all \
      --sort-by TIME_ACCEPTED \
      --sort-order DESC || true
    fixture_oci_capture "$cluster_wr_file" "$cluster_wr_stderr" \
      ce work-request list \
      --compartment-id "$TF_VAR_cluster_compartment_id" \
      --cluster-id "$cluster_id" \
      --all \
      --sort-by TIME_ACCEPTED \
      --sort-order DESC || true
  fi

  local work_request_id=""
  work_request_id="$(enhanced_fixture_select_latest_work_request_id "$nodepool_wr_file" "$cluster_wr_file")"

  if [ -n "$work_request_id" ]; then
    fixture_oci_capture "$work_request_file" "$work_request_stderr" \
      ce work-request get \
      --work-request-id "$work_request_id" || true
    fixture_oci_capture "$work_request_errors_file" "$work_request_errors_stderr" \
      ce work-request-error list \
      --compartment-id "$TF_VAR_cluster_compartment_id" \
      --work-request-id "$work_request_id" \
      --all || true
  fi

  enhanced_fixture_write_summary \
    "$summary_file" \
    "$reason" \
    "$cluster_id" \
    "$expected_size" \
    "$expected_public" \
    "$expected_cloud_init" \
    "$cluster_file" \
    "$node_pools_file" \
    "$work_request_id" \
    "$outputs_file"
}

enhanced_fixture_validate() {
  local fixture_dir="$1"
  local artifact_dir="$2"
  local expected_size="$3"
  local expected_public="$4"
  local expected_cloud_init="$5"

  local cluster_id
  cluster_id="$(enhanced_fixture_cluster_id "$fixture_dir")"

  if [ -z "$cluster_id" ]; then
    printf 'Cluster ID could not be resolved from fixture state after apply.\n' >"$artifact_dir/validator-summary.txt"
    enhanced_fixture_collect_diagnostics \
      "$fixture_dir" \
      "$artifact_dir" \
      "cluster id unavailable after apply" \
      "$expected_size" \
      "$expected_public" \
      "$expected_cloud_init"
    return 1
  fi

  local summary_file="$artifact_dir/validator-summary.txt"
  local outputs_file="$artifact_dir/outputs.json"
  : >"$summary_file"

  local deadline=$((SECONDS + 900))
  local attempt=0
  while [ "$SECONDS" -lt "$deadline" ]; do
    attempt=$((attempt + 1))

    local cluster_file="$artifact_dir/live-cluster.json"
    local cluster_stderr="$artifact_dir/live-cluster.stderr"
    local node_pools_file="$artifact_dir/live-node-pools.json"
    local node_pools_stderr="$artifact_dir/live-node-pools.stderr"

    fixture_oci_capture "$cluster_file" "$cluster_stderr" ce cluster get --cluster-id "$cluster_id" || true
    fixture_oci_capture "$node_pools_file" "$node_pools_stderr" \
      ce node-pool list \
      --compartment-id "$TF_VAR_cluster_compartment_id" \
      --cluster-id "$cluster_id" \
      --all || true

    local cluster_state cluster_public node_pool_count active_node_pool_count max_node_pool_size cloud_init_node_pool_count ready
    cluster_state="$(jq -r '
      try (
        .data."lifecycle-state"
        // .data.lifecycleState
        // .data.lifecycle_state
        // .data.state
        // "unknown"
      )
    ' "$cluster_file" 2>/dev/null || printf 'unknown\n')"
    cluster_public="$(enhanced_fixture_cluster_public_value "$cluster_file")"
    node_pool_count="$(jq -r 'try (.data | length) // 0' "$node_pools_file" 2>/dev/null || printf '0\n')"
    active_node_pool_count="$(jq -r '
      [
        try (.data // [])[] |
        select(
          (
            ."lifecycle-state"
            // .lifecycleState
            // .lifecycle_state
            // .state
            // ""
          ) == "ACTIVE"
        )
      ] | length
    ' "$node_pools_file" 2>/dev/null || printf '0\n')"
    max_node_pool_size="$(jq -r '
      [
        try (.data // [])[] |
        (
          ."node-config-details".size
          // .nodeConfigDetails.size
          // .node_config_details.size
          // 0
        )
      ] | max // 0
    ' "$node_pools_file" 2>/dev/null || printf '0\n')"
    if [ "$cluster_public" = "unknown" ]; then
      cluster_public="$(enhanced_fixture_requested_output_bool "$outputs_file" is_public_endpoint)"
    fi
    cloud_init_node_pool_count="$(enhanced_fixture_cloud_init_node_pool_count "$node_pools_file" "$outputs_file" "$node_pool_count")"

    ready="false"
    if [ "$cluster_state" = "ACTIVE" ] \
      && [ "$cluster_public" = "$expected_public" ] \
      && [ "$node_pool_count" -ge 1 ] \
      && [ "$active_node_pool_count" -ge 1 ] \
      && [ "$max_node_pool_size" -ge "$expected_size" ]; then
      if [ "$expected_cloud_init" = "true" ]; then
        if [ "$cloud_init_node_pool_count" -ge 1 ]; then
          ready="true"
        fi
      else
        ready="true"
      fi
    fi

    local status_line
    status_line="$(printf '%s attempt=%s cluster_state=%s cluster_public=%s node_pools=%s active_node_pools=%s max_size=%s cloud_init_node_pools=%s ready=%s' \
      "$(timestamp_utc)" \
      "$attempt" \
      "$cluster_state" \
      "$cluster_public" \
      "$node_pool_count" \
      "$active_node_pool_count" \
      "$max_node_pool_size" \
      "$cloud_init_node_pool_count" \
      "$ready")"
    printf '%s\n' "$status_line" >>"$summary_file"
    log "$status_line"

    if [ "$ready" = "true" ]; then
      return 0
    fi

    sleep 30
  done

  printf '%s validation timed out after waiting for enhanced fixture readiness.\n' "$(timestamp_utc)" >>"$summary_file"
  enhanced_fixture_collect_diagnostics \
    "$fixture_dir" \
    "$artifact_dir" \
    "validation timeout waiting for enhanced fixture readiness" \
    "$expected_size" \
    "$expected_public" \
    "$expected_cloud_init"
  return 1
}

fixture_requires_enhanced_health_checks() {
  local target="$1"
  local action="$2"
  [ "$target" = "enhanced" ] || return 1
  case "$action" in
    up|refresh|scale)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

run_fixture_terraform() {
  local fixture_dir="$1"
  local action="$2"
  local artifact_dir="$3"
  shift 3

  require_command terraform
  assert_fixture_config_exists "$fixture_dir"

  local init_args=()
  while IFS= read -r arg; do
    [ -n "$arg" ] && init_args+=("$arg")
  done < <(terraform_init_args)

  terraform -chdir="$fixture_dir" init "${init_args[@]}" >"$artifact_dir/terraform-init.log" 2>&1

  case "$action" in
    status)
      fixture_capture_outputs "$fixture_dir" "$artifact_dir/outputs.json" || true
      ;;
    up)
      set +e
      terraform -chdir="$fixture_dir" apply -input=false -auto-approve "$@" >"$artifact_dir/terraform-apply.log" 2>&1
      local apply_status=$?
      set -e
      fixture_capture_outputs "$fixture_dir" "$artifact_dir/outputs.json" || true
      return "$apply_status"
      ;;
    down)
      set +e
      terraform -chdir="$fixture_dir" destroy -input=false -auto-approve "$@" >"$artifact_dir/terraform-destroy.log" 2>&1
      local destroy_status=$?
      set -e
      return "$destroy_status"
      ;;
    refresh)
      set +e
      terraform -chdir="$fixture_dir" destroy -input=false -auto-approve "$@" >"$artifact_dir/terraform-destroy.log" 2>&1
      local refresh_destroy_status=$?
      set -e
      if [ "$refresh_destroy_status" -ne 0 ]; then
        fixture_capture_outputs "$fixture_dir" "$artifact_dir/outputs.json" || true
        return "$refresh_destroy_status"
      fi

      set +e
      terraform -chdir="$fixture_dir" apply -input=false -auto-approve "$@" >"$artifact_dir/terraform-apply.log" 2>&1
      local refresh_apply_status=$?
      set -e
      fixture_capture_outputs "$fixture_dir" "$artifact_dir/outputs.json" || true
      return "$refresh_apply_status"
      ;;
    *)
      die "Unsupported terraform fixture action: $action"
      ;;
  esac
}

run_fixture_action() {
  local target="$1"
  local action="$2"
  local size="${3:-}"
  local extra_vars=()
  require_non_empty "$target" "TARGET is required for fixture command"
  require_non_empty "$action" "ACTION is required for fixture command"

  assert_fixture_env_ready "$target"
  if fixture_requires_enhanced_health_checks "$target" "$action"; then
    require_command jq
    require_command oci
  fi

  if [ "$target" = "network" ] && { [ "$action" = "down" ] || [ "$action" = "refresh" ]; }; then
    assert_network_destroy_is_safe
  fi
  if [ "$target" != "network" ] && { [ "$action" = "up" ] || [ "$action" = "refresh" ] || [ "$action" = "scale" ]; }; then
    assert_network_fixture_ready
  fi

  local fixture_dir
  fixture_dir="$(fixture_dir_for_target "$target")"
  local artifact_dir
  artifact_dir="$(create_artifact_dir "fixture/$target/$action")"
  local expected_size="0"
  local expected_cloud_init="false"
  local expected_public_endpoint="false"
  local requested_size=""
  local requested_cloud_init=""
  local requested_public_endpoint=""
  log "Running fixture action '$action' for target '$target'"

  if ! fixture_has_config "$fixture_dir"; then
    if [ "$action" = "status" ]; then
      printf '{ "status": "scaffolded", "fixture_dir": "%s" }\n' "$fixture_dir" >"$artifact_dir/status.json"
      log "Fixture workspace is scaffolded but not yet implemented: $fixture_dir"
      return 0
    fi
    die "Fixture workspace is scaffolded but has no Terraform files yet: $fixture_dir"
  fi

  case "$action" in
    status|up|down|refresh)
      if [ "$target" = "enhanced" ] && [ -n "$size" ]; then
        extra_vars+=("-var=node_pool_size=$size")
      fi
      if [ "$target" = "enhanced" ] && [ -n "${USE_CUSTOM_CLOUD_INIT:-}" ]; then
        extra_vars+=("-var=use_custom_cloud_init=$USE_CUSTOM_CLOUD_INIT")
      fi
      if [ "$target" = "enhanced" ] && [ -n "${IS_PUBLIC_ENDPOINT:-}" ]; then
        extra_vars+=("-var=is_public_endpoint=$IS_PUBLIC_ENDPOINT")
      fi
      ;;
    scale)
      [ "$target" = "enhanced" ] || die "Scale action is only supported for TARGET=enhanced"
      require_non_empty "$size" "SIZE is required for fixture scale action"
      if [ -n "${USE_CUSTOM_CLOUD_INIT:-}" ]; then
        extra_vars+=("-var=use_custom_cloud_init=$USE_CUSTOM_CLOUD_INIT")
      fi
      if [ -n "${IS_PUBLIC_ENDPOINT:-}" ]; then
        extra_vars+=("-var=is_public_endpoint=$IS_PUBLIC_ENDPOINT")
      fi
      action="up"
      if [ "${#extra_vars[@]}" -gt 0 ]; then
        extra_vars=("-var=node_pool_size=$size" "${extra_vars[@]}")
      else
        extra_vars=("-var=node_pool_size=$size")
      fi
      ;;
    *)
      die "Unknown fixture action: $action"
      ;;
  esac

  if fixture_requires_enhanced_health_checks "$target" "$action"; then
    expected_size="$(enhanced_fixture_expected_size "$size")"
    expected_cloud_init="$(enhanced_fixture_expected_cloud_init)"
    expected_public_endpoint="$(enhanced_fixture_expected_public_endpoint)"
  fi

  case "$target" in
    enhanced)
      requested_size="${expected_size:-$(enhanced_fixture_expected_size "$size")}"
      requested_cloud_init="${expected_cloud_init:-$(enhanced_fixture_expected_cloud_init)}"
      requested_public_endpoint="${expected_public_endpoint:-$(enhanced_fixture_expected_public_endpoint)}"
      ;;
    network|basic)
      requested_size="$size"
      requested_cloud_init="${USE_CUSTOM_CLOUD_INIT:-}"
      requested_public_endpoint="${IS_PUBLIC_ENDPOINT:-}"
      ;;
  esac

  if [ "$action" = "up" ] && fixture_matches_requested_state \
    "$target" \
    "$requested_size" \
    "$requested_cloud_init" \
    "$requested_public_endpoint"; then
    log "Fixture target '$target' already matches the requested state; skipping terraform apply."
    if fixture_requires_enhanced_health_checks "$target" "$action"; then
      if ! enhanced_fixture_validate \
        "$fixture_dir" \
        "$artifact_dir" \
        "$expected_size" \
        "$expected_public_endpoint" \
        "$expected_cloud_init"; then
        return 1
      fi
    fi

    cleanup_artifact_dir_on_success "$artifact_dir"
    if should_keep_success_artifacts; then
      log "Fixture action completed. Artifacts: $artifact_dir"
    else
      log "Fixture action completed. Successful artifacts cleaned."
    fi
    return 0
  fi

  local fixture_status=0
  if [ "${#extra_vars[@]}" -gt 0 ]; then
    run_fixture_terraform "$fixture_dir" "$action" "$artifact_dir" "${extra_vars[@]}" || fixture_status=$?
  else
    run_fixture_terraform "$fixture_dir" "$action" "$artifact_dir" || fixture_status=$?
  fi
  if [ "$fixture_status" -ne 0 ]; then
    if fixture_requires_enhanced_health_checks "$target" "$action"; then
      enhanced_fixture_collect_diagnostics \
        "$fixture_dir" \
        "$artifact_dir" \
        "terraform $action failed" \
        "$expected_size" \
        "$expected_public_endpoint" \
        "$expected_cloud_init"
    fi
    return "$fixture_status"
  fi

  if fixture_requires_enhanced_health_checks "$target" "$action"; then
    if ! enhanced_fixture_validate \
      "$fixture_dir" \
      "$artifact_dir" \
      "$expected_size" \
      "$expected_public_endpoint" \
      "$expected_cloud_init"; then
      return 1
    fi
  fi

  cleanup_artifact_dir_on_success "$artifact_dir"
  if should_keep_success_artifacts; then
    log "Fixture action completed. Artifacts: $artifact_dir"
  else
    log "Fixture action completed. Successful artifacts cleaned."
  fi
}

destroy_all_fixtures() {
  local targets=(enhanced basic network)
  local target
  local failed=()

  log "Destroying all fixture workspaces in dependency order: ${targets[*]}"

  for target in "${targets[@]}"; do
    if ! run_fixture_action "$target" down; then
      failed+=("$target")
    fi
  done

  if [ "${#failed[@]}" -gt 0 ]; then
    die "Failed to destroy fixture targets: ${failed[*]}"
  fi

  log "All fixture workspaces destroyed."
}
