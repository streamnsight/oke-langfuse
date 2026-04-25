#!/usr/bin/env bash

devops_oci_capture() {
  local stdout_file="$1"
  local stderr_file="$2"
  shift 2

  local oci_args=()
  while IFS= read -r arg; do
    [ -n "$arg" ] && oci_args+=("$arg")
  done < <(oci_cli_global_args)

  oci "${oci_args[@]}" "$@" >"$stdout_file" 2>"$stderr_file" || true
}

devops_collect_pipeline_ids() {
  local outputs_json="$1"
  local pipelines_file="$2"

  {
    printf '%s\n' "$outputs_json" | jq -r '
      try .test_metadata.value.devops.pipeline_ids // {} |
      to_entries[] |
      select(.value != null and .value != "") |
      .value
    '
    if [ -f "$pipelines_file" ]; then
      jq -r '
        try .data.items // [] |
        .[] |
        (.id // empty)
      ' "$pipelines_file"
    fi
  } | awk '!seen[$0]++'
}

devops_select_deployment_id() {
  local outputs_json="$1"
  local deployments_file="$2"
  local pipeline_ids_json="$3"

  if [ -n "${DEPLOYMENT_ID:-}" ]; then
    printf '%s\n' "$DEPLOYMENT_ID"
    return
  fi

  local deployment_id
  deployment_id="$(printf '%s\n' "$outputs_json" | jq -r '
    try .test_metadata.value.devops.deployment_ids // {} |
    to_entries |
    map(select(.value != null and .value != "")) |
    .[0].value // empty
  ')"
  if [ -n "$deployment_id" ]; then
    printf '%s\n' "$deployment_id"
    return
  fi

  if [ -f "$deployments_file" ]; then
    deployment_id="$(jq -r --argjson pipeline_ids "$pipeline_ids_json" '
      def pipeline_values:
        ($pipeline_ids | to_entries | map(select(.value != null and .value != "")) | map(.value));
      (
        try .data.items // [] |
        map(select((.deployPipelineId // .["deploy-pipeline-id"] // "") as $id | pipeline_values | index($id))) |
        .[0].id
      ) // (
        try .data.items // [] |
        .[0].id
      ) // empty
    ' "$deployments_file" 2>/dev/null || true)"
    if [ -n "$deployment_id" ]; then
      printf '%s\n' "$deployment_id"
    fi
  fi
}

devops_write_summary() {
  local summary_file="$1"
  local request_file="$2"
  local pipelines_file="$3"
  local deployments_file="$4"
  local deployment_file="$5"
  local named_deployments_dir="${6:-}"

  {
    printf 'DevOps Debug Summary\n'
    printf '====================\n'
    jq -r '
      "Target: \(.target)",
      "Project ID: \(.project_id // "")",
      "Environment ID: \(.environment_id // "")",
      "Selected Deployment ID: \(.selected_deployment_id // "")"
    ' "$request_file"

    if [ -f "$pipelines_file" ]; then
      printf '\nPipelines\n'
      jq -r '
        try .data.items // [] |
        if length == 0 then
          "- none discovered"
        else
          .[] |
          "- \(.displayName // .display_name // "unnamed") [\(.id // "")]"
        end
      ' "$pipelines_file" 2>/dev/null || printf '%s\n' '- unavailable'
    fi

    if [ -f "$deployments_file" ]; then
      printf '\nRecent Deployments\n'
      jq -r '
        try .data.items // [] |
        if length == 0 then
          "- none discovered"
        else
          .[:10][] |
          "- \(.displayName // .display_name // "unnamed") [\(.id // "")] state=\(.lifecycleState // .lifecycle_state // "unknown") time=\(.timeCreated // .time_created // "unknown")"
        end
      ' "$deployments_file" 2>/dev/null || printf '%s\n' '- unavailable'
    fi

    if [ -f "$deployment_file" ]; then
      printf '\nSelected Deployment\n'
      jq -r '
        .data // . |
        "Display Name: \(.displayName // .display_name // "unknown")",
        "ID: \(.id // "")",
        "Pipeline ID: \(.deployPipelineId // .["deploy-pipeline-id"] // "")",
        "State: \(.lifecycleState // .lifecycle_state // "unknown")",
        "Time Created: \(.timeCreated // .time_created // "unknown")"
      ' "$deployment_file" 2>/dev/null || printf '%s\n' 'Unavailable'
    fi

    if [ -n "$named_deployments_dir" ] && [ -d "$named_deployments_dir" ]; then
      printf '\nNamed Deployments\n'
      local deployment_summary_found="false"
      local deployment_summary_file
      for deployment_summary_file in "$named_deployments_dir"/*.summary.txt; do
        [ -f "$deployment_summary_file" ] || continue
        deployment_summary_found="true"
        cat "$deployment_summary_file"
      done
      if [ "$deployment_summary_found" != "true" ]; then
        printf '%s\n' '- none discovered'
      fi
    fi
  } >"$summary_file"
}

collect_devops_debug() {
  local target="$1"
  local debug_dir="$2"

  require_command oci
  require_command jq

  local devops_dir="$debug_dir/devops"
  mkdir -p "$devops_dir"

  local stack_outputs project_id environment_id selected_deployment_id
  local pipeline_ids_json deployment_ids_json
  stack_outputs="$(root_stack_outputs_json)"
  printf '%s\n' "$stack_outputs" >"$devops_dir/root-stack-outputs.json"

  project_id="${PROJECT_ID:-$(printf '%s\n' "$stack_outputs" | jq -r 'try .test_metadata.value.devops.project_id // empty')}"
  environment_id="$(printf '%s\n' "$stack_outputs" | jq -r 'try .test_metadata.value.devops.environment_id // empty')"
  pipeline_ids_json="$(printf '%s\n' "$stack_outputs" | jq -c 'try .test_metadata.value.devops.pipeline_ids // {}')"
  deployment_ids_json="$(printf '%s\n' "$stack_outputs" | jq -c 'try .test_metadata.value.devops.deployment_ids // {}')"

  local pipelines_file="$devops_dir/pipelines.json"
  local deployments_file="$devops_dir/deployments.json"
  local deployment_file="$devops_dir/deployment.json"
  local summary_file="$devops_dir/summary.txt"
  local named_deployments_dir="$devops_dir/named-deployments"
  mkdir -p "$named_deployments_dir"

  if [ -n "$project_id" ]; then
    devops_oci_capture \
      "$pipelines_file" \
      "$devops_dir/pipelines.stderr" \
      devops deploy-pipeline list \
      --project-id "$project_id" \
      --all

    devops_oci_capture \
      "$deployments_file" \
      "$devops_dir/deployments.stderr" \
      devops deployment list \
      --project-id "$project_id" \
      --sort-by timeCreated \
      --sort-order DESC \
      --all
  fi

  selected_deployment_id="$(devops_select_deployment_id "$stack_outputs" "$deployments_file" "$pipeline_ids_json")"

  jq -n \
    --arg target "$target" \
    --arg project_id "$project_id" \
    --arg environment_id "$environment_id" \
    --arg selected_deployment_id "$selected_deployment_id" \
    --argjson pipeline_ids "$pipeline_ids_json" \
    --argjson deployment_ids "$deployment_ids_json" '
      {
        target: $target,
        project_id: $project_id,
        environment_id: $environment_id,
        selected_deployment_id: $selected_deployment_id,
        pipeline_ids: $pipeline_ids,
        deployment_ids: $deployment_ids
      }
    ' >"$devops_dir/request.json"

  local pipeline_id
  while IFS= read -r pipeline_id; do
    [ -n "$pipeline_id" ] || continue
    local pipeline_dir="$devops_dir/pipelines/$(slugify "$pipeline_id")"
    mkdir -p "$pipeline_dir/stages"

    devops_oci_capture \
      "$pipeline_dir/pipeline.json" \
      "$pipeline_dir/pipeline.stderr" \
      devops deploy-pipeline get \
      --pipeline-id "$pipeline_id"

    devops_oci_capture \
      "$pipeline_dir/stages.json" \
      "$pipeline_dir/stages.stderr" \
      devops deploy-stage list \
      --pipeline-id "$pipeline_id" \
      --all

    local stage_id
    while IFS= read -r stage_id; do
      [ -n "$stage_id" ] || continue
      devops_oci_capture \
        "$pipeline_dir/stages/$(slugify "$stage_id").json" \
        "$pipeline_dir/stages/$(slugify "$stage_id").stderr" \
        devops deploy-stage get \
        --stage-id "$stage_id"
    done < <(jq -r 'try .data.items // [] | .[] | (.id // empty)' "$pipeline_dir/stages.json" 2>/dev/null)

    devops_oci_capture \
      "$pipeline_dir/deployments.json" \
      "$pipeline_dir/deployments.stderr" \
      devops deployment list \
      --pipeline-id "$pipeline_id" \
      --sort-by timeCreated \
      --sort-order DESC \
      --all
  done < <(devops_collect_pipeline_ids "$stack_outputs" "$pipelines_file")

  if [ -n "$selected_deployment_id" ]; then
    devops_oci_capture \
      "$deployment_file" \
      "$devops_dir/deployment.stderr" \
      devops deployment get \
      --deployment-id "$selected_deployment_id"
  fi

  local deployment_name deployment_id deployment_slug
  while IFS=$'\t' read -r deployment_name deployment_id; do
    [ -n "$deployment_name" ] || continue
    [ -n "$deployment_id" ] || continue

    deployment_slug="$(slugify "$deployment_name")"
    devops_oci_capture \
      "$named_deployments_dir/$deployment_slug.json" \
      "$named_deployments_dir/$deployment_slug.stderr" \
      devops deployment get \
      --deployment-id "$deployment_id"

    jq -r --arg name "$deployment_name" '
      .data // . |
      [
        "- " + $name,
        "  id=" + (.id // ""),
        "  pipeline_id=" + (.deployPipelineId // .["deploy-pipeline-id"] // ""),
        "  state=" + (.lifecycleState // .lifecycle_state // "unknown"),
        "  time_created=" + (.timeCreated // .time_created // "unknown")
      ] | .[]
    ' "$named_deployments_dir/$deployment_slug.json" >"$named_deployments_dir/$deployment_slug.summary.txt" 2>/dev/null || true
  done < <(
    printf '%s\n' "$stack_outputs" | jq -r '
      try .test_metadata.value.devops.deployment_ids // {} |
      to_entries[] |
      select(.value != null and .value != "") |
      [.key, .value] | @tsv
    '
  )

  devops_write_summary \
    "$summary_file" \
    "$devops_dir/request.json" \
    "$pipelines_file" \
    "$deployments_file" \
    "$deployment_file" \
    "$named_deployments_dir"
}
