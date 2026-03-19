#!/usr/bin/env bash

collect_devops_debug() {
  local target="$1"
  local debug_dir="$2"

  require_command oci
  require_command jq

  local devops_dir="$debug_dir/devops"
  mkdir -p "$devops_dir"

  {
    printf '{\n'
    printf '  "target": "%s",\n' "$target"
    printf '  "project_id": "%s",\n' "${PROJECT_ID:-}"
    printf '  "pipeline_id": "%s",\n' "${PIPELINE_ID:-}"
    printf '  "deployment_id": "%s"\n' "${DEPLOYMENT_ID:-}"
    printf '}\n'
  } >"$devops_dir/request.json"

  if [ -n "${PROJECT_ID:-}" ]; then
    oci devops deploy-pipeline list \
      --project-id "$PROJECT_ID" \
      --all >"$devops_dir/pipelines.json" 2>"$devops_dir/pipelines.stderr" || true
  fi

  if [ -n "${DEPLOYMENT_ID:-}" ]; then
    oci devops deployment get \
      --deployment-id "$DEPLOYMENT_ID" >"$devops_dir/deployment.json" 2>"$devops_dir/deployment.stderr" || true
  fi
}
