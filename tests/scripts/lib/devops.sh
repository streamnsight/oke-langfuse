#!/usr/bin/env bash

collect_devops_debug() {
  local target="$1"
  local debug_dir="$2"

  require_command oci
  require_command jq

  local devops_dir="$debug_dir/devops"
  mkdir -p "$devops_dir"

  local stack_outputs project_id pipeline_id deployment_id
  stack_outputs="$(root_stack_outputs_json)"
  project_id="${PROJECT_ID:-$(printf '%s\n' "$stack_outputs" | jq -r 'try .test_metadata.value.devops.project_id // empty')}"
  pipeline_id="${PIPELINE_ID:-}"
  deployment_id="${DEPLOYMENT_ID:-}"

  {
    printf '{\n'
    printf '  "target": "%s",\n' "$target"
    printf '  "project_id": "%s",\n' "$project_id"
    printf '  "pipeline_id": "%s",\n' "$pipeline_id"
    printf '  "deployment_id": "%s"\n' "$deployment_id"
    printf '}\n'
  } >"$devops_dir/request.json"

  printf '%s\n' "$stack_outputs" >"$devops_dir/root-stack-outputs.json"

  if [ -n "$project_id" ]; then
    oci devops deploy-pipeline list \
      --project-id "$project_id" \
      --all >"$devops_dir/pipelines.json" 2>"$devops_dir/pipelines.stderr" || true
  fi

  if [ -n "$deployment_id" ]; then
    oci devops deployment get \
      --deployment-id "$deployment_id" >"$devops_dir/deployment.json" 2>"$devops_dir/deployment.stderr" || true
  fi
}
