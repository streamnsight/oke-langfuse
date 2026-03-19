#!/usr/bin/env bash

TESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$TESTS_LIB_DIR/../.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
ARTIFACTS_DIR="$TESTS_DIR/artifacts"

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
