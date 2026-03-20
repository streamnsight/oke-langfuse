#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${1:?workdir is required}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=tests/scripts/lib/common.sh
source "$TESTS_DIR/scripts/lib/common.sh"
# shellcheck source=tests/scripts/lib/fixtures.sh
source "$TESTS_DIR/scripts/lib/fixtures.sh"
# shellcheck source=tests/scripts/lib/scenarios.sh
source "$TESTS_DIR/scripts/lib/scenarios.sh"

cluster_id="$(fixture_output_value enhanced cluster_id)"
export STACK_TEST_INCLUDE_IDCS_PLACEHOLDERS=false
write_existing_cluster_with_network_tfvars \
  "$WORK_DIR/terraform.tfvars" \
  "$cluster_id" \
  "enable_existing_cluster_cloud_init_preflight = true"
unset STACK_TEST_INCLUDE_IDCS_PLACEHOLDERS

append_live_identity_tfvars "$WORK_DIR/terraform.tfvars"
