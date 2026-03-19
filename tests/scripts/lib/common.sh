#!/usr/bin/env bash

TESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$TESTS_LIB_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
ARTIFACTS_DIR="$TESTS_DIR/artifacts"
TF_PLUGIN_DIR="$ROOT_DIR/.terraform/providers"
TESTS_ENV_FILE="${TESTS_ENV_FILE:-$TESTS_DIR/.env}"
TESTS_ENV_LOCAL_FILE="${TESTS_ENV_LOCAL_FILE:-$TESTS_DIR/.env.local}"

log() {
  printf '[tests] %s\n' "$*"
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

terraform_init_args() {
  local args=(-backend=false -input=false)
  if [ -d "$TF_PLUGIN_DIR" ]; then
    args+=("-plugin-dir=$TF_PLUGIN_DIR")
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
}

load_tests_env
