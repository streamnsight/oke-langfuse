#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=tests/scripts/lib/terraform.sh
source "$SCRIPT_DIR/lib/terraform.sh"
# shellcheck source=tests/scripts/lib/fixtures.sh
source "$SCRIPT_DIR/lib/fixtures.sh"
# shellcheck source=tests/scripts/lib/scenarios.sh
source "$SCRIPT_DIR/lib/scenarios.sh"
# shellcheck source=tests/scripts/lib/devops.sh
source "$SCRIPT_DIR/lib/devops.sh"
# shellcheck source=tests/scripts/lib/kube.sh
source "$SCRIPT_DIR/lib/kube.sh"

print_help() {
  cat <<'EOF'
Usage:
  tests/scripts/run.sh <command>

Commands:
  help
  test      Run preflight plus scenario validation. Optional: SCENARIO=<name> SUITE=<all|fast|live>
            Live suites self-bootstrap fixture profiles from empty local state, reorder them to reduce cluster churn, require TF_VAR_fixture_operating_system / TF_VAR_fixture_operating_system_version / TF_VAR_fixture_shape from tests/.env or tests/.env.local, and may set LIVE_FIXTURE_FINAL_CLEANUP=success.
  fixture   Manage fixture workspace. Required: TARGET=<network|basic|enhanced> ACTION=<up|down|refresh|status|scale>
  fixture-prewarm  Prewarm the ordered live-suite fixture footprint ahead of a run. Optional: SUITE=live
            Uses the same required live selector env vars as SUITE=live. TF_VAR_fixture_node_image_id remains a manual recovery override.
  fixture-down-all  Destroy all fixture workspaces in dependency order. Manual cleanup only.
  cleanup-failed-stack  Destroy a preserved failed full-stack workdir. Required: STACK_DIR=<path>
  debug     Collect OCI DevOps and Kubernetes diagnostics. Required: TARGET=<network|basic|enhanced>

Examples:
  ./tests/scripts/run.sh test
  ./tests/scripts/run.sh test SUITE=fast
  ./tests/scripts/run.sh test SUITE=live
  ./tests/scripts/run.sh fixture-prewarm
  ./tests/scripts/run.sh test SUITE=live LIVE_FIXTURE_FINAL_CLEANUP=success
  ./tests/scripts/run.sh test SCENARIO=existing_cluster/invalid_empty_cluster_ocid
  ./tests/scripts/run.sh test SUITE=all SCENARIO=networking/valid_existing_vcn
  ./tests/scripts/run.sh fixture ACTION=status TARGET=network
  ./tests/scripts/run.sh fixture ACTION=scale TARGET=enhanced SIZE=3
  ./tests/scripts/run.sh fixture ACTION=refresh TARGET=enhanced USE_CUSTOM_CLOUD_INIT=false
  ./tests/scripts/run.sh fixture-down-all
  ./tests/scripts/run.sh cleanup-failed-stack STACK_DIR=tests/artifacts/failed-stacks/deployment_valid_existing_cluster_existing_vcn
  ./tests/scripts/run.sh debug TARGET=enhanced
EOF
}

COMMAND="${1:-help}"
shift || true

for arg in "$@"; do
  case "$arg" in
    *=*)
      export "$arg"
      ;;
    *)
      die "Unexpected argument: $arg"
      ;;
  esac
done

case "$COMMAND" in
  help|-h|--help)
    print_help
    ;;
  test)
    export SUITE="${SUITE:-fast}"
    run_scenario_suite "${SCENARIO:-}"
    ;;
  fixture)
    run_fixture_action "${TARGET:-}" "${ACTION:-}" "${SIZE:-}"
    ;;
  fixture-prewarm)
    export SUITE="${SUITE:-live}"
    prewarm_live_fixture_suite
    ;;
  fixture-down-all)
    destroy_all_fixtures
    ;;
  cleanup-failed-stack)
    cleanup_failed_stack_dir "${STACK_DIR:-}"
    ;;
  debug)
    TARGET="${TARGET:-}"
    require_non_empty "$TARGET" "TARGET is required for debug"
    debug_dir="$(create_artifact_dir "debug/$TARGET")"
    log "Writing debug bundle to $debug_dir"
    collect_devops_debug "$TARGET" "$debug_dir"
    collect_cluster_debug "$TARGET" "$debug_dir"
    ;;
  *)
    die "Unknown command: $COMMAND"
    ;;
esac
