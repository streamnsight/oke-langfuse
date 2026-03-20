#!/usr/bin/env bash

TESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$TESTS_LIB_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
ARTIFACTS_DIR="$TESTS_DIR/artifacts"
TF_PLUGIN_DIR="$ROOT_DIR/.terraform/providers"
TESTS_ENV_FILE="${TESTS_ENV_FILE:-$TESTS_DIR/.env}"
TESTS_ENV_LOCAL_FILE="${TESTS_ENV_LOCAL_FILE:-$TESTS_DIR/.env.local}"
ROOT_TERRAFORM_STATE_FILE="${ROOT_TERRAFORM_STATE_FILE:-$ROOT_DIR/terraform.tfstate}"
TESTS_KEEP_SUCCESS_ARTIFACTS="${TESTS_KEEP_SUCCESS_ARTIFACTS:-false}"
TESTS_STREAM_LOGS="${TESTS_STREAM_LOGS:-${GITHUB_ACTIONS:-false}}"

log() {
  printf '[tests] %s\n' "$*"
}

begin_log_group() {
  local label="$1"
  if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
    printf '::group::%s\n' "$label"
  else
    log "$label"
  fi
}

end_log_group() {
  if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
    printf '::endgroup::\n'
  fi
}

die() {
  printf '[tests] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_non_empty() {
  local value="$1"
  local message="$2"
  [ -n "$value" ] || die "$message"
}

timestamp_utc() {
  date -u +"%Y%m%dT%H%M%SZ"
}

slugify() {
  printf '%s' "$1" | tr '/ ' '__' | tr -cd '[:alnum:]_.-'
}

create_artifact_dir() {
  local category="$1"
  local dir="$ARTIFACTS_DIR/$category/$(timestamp_utc)"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

ensure_artifacts_dir() {
  mkdir -p "$ARTIFACTS_DIR"
}

should_keep_success_artifacts() {
  [ "$TESTS_KEEP_SUCCESS_ARTIFACTS" = "true" ]
}

should_stream_logs() {
  [ "$TESTS_STREAM_LOGS" = "true" ]
}

cleanup_artifact_dir_on_success() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  if should_keep_success_artifacts; then
    return 0
  fi
  rm -rf "$dir"
}

terraform_init_args() {
  local args=(-backend=false -input=false)
  if [ -d "$TF_PLUGIN_DIR" ]; then
    args+=("-plugin-dir=$TF_PLUGIN_DIR")
  fi
  printf '%s\n' "${args[@]}"
}

oci_cli_global_args() {
  local args=()
  if [ -n "${OCI_PROFILE:-}" ]; then
    args+=("--profile" "$OCI_PROFILE")
  fi
  if [ -n "${TF_VAR_region:-}" ]; then
    args+=("--region" "$TF_VAR_region")
  fi
  printf '%s\n' "${args[@]}"
}

load_env_file() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    log "Loaded environment from $env_file"
  fi
}

load_tests_env() {
  load_env_file "$TESTS_ENV_FILE"
  load_env_file "$TESTS_ENV_LOCAL_FILE"

  if [ -z "${TF_PLUGIN_CACHE_DIR:-}" ]; then
    export TF_PLUGIN_CACHE_DIR="$TESTS_DIR/.terraform.d/plugin-cache"
  fi
  if [ -n "${TF_PLUGIN_CACHE_DIR:-}" ]; then
    mkdir -p "$TF_PLUGIN_CACHE_DIR"
  fi

  if [ -z "${TF_VAR_compartment_id:-}" ] && [ -n "${TF_VAR_vcn_compartment_id:-}" ]; then
    export TF_VAR_compartment_id="$TF_VAR_vcn_compartment_id"
  fi

  if [ -z "${TF_VAR_fixture_node_image_id:-}" ] && [ -n "${TF_VAR_np1_image_id:-}" ]; then
    export TF_VAR_fixture_node_image_id="$TF_VAR_np1_image_id"
  fi
}

root_stack_outputs_json() {
  if [ -f "$ROOT_TERRAFORM_STATE_FILE" ]; then
    terraform -chdir="$ROOT_DIR" output -json 2>/dev/null || printf '{}\n'
  else
    printf '{}\n'
  fi
}

load_tests_env
