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
  fixture   Manage fixture workspace. Required: TARGET=<network|basic|enhanced> ACTION=<up|down|refresh|status|scale>
  debug     Collect OCI DevOps and Kubernetes diagnostics. Required: TARGET=<network|basic|enhanced>

Examples:
  ./tests/scripts/run.sh test
  ./tests/scripts/run.sh test SUITE=fast
  ./tests/scripts/run.sh test SUITE=live
  ./tests/scripts/run.sh test SCENARIO=existing_cluster/invalid_empty_cluster_ocid
  ./tests/scripts/run.sh test SUITE=all SCENARIO=networking/valid_existing_vcn
  ./tests/scripts/run.sh fixture ACTION=status TARGET=network
  ./tests/scripts/run.sh fixture ACTION=scale TARGET=enhanced SIZE=3
  ./tests/scripts/run.sh fixture ACTION=refresh TARGET=enhanced USE_CUSTOM_CLOUD_INIT=false
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
