#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${1:?workdir is required}"
ARTIFACT_DIR="${TESTS_SCENARIO_ARTIFACT_DIR:-$WORK_DIR/tests/artifacts/managed-cluster}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=tests/scripts/lib/common.sh
source "$TESTS_DIR/scripts/lib/common.sh"
# shellcheck source=tests/scripts/lib/fixtures.sh
source "$TESTS_DIR/scripts/lib/fixtures.sh"
# shellcheck source=tests/scripts/lib/scenarios.sh
source "$TESTS_DIR/scripts/lib/scenarios.sh"

require_command jq
require_command oci

assert_network_fixture_ready
mkdir -p "$ARTIFACT_DIR"

rm -f "$WORK_DIR/terraform.tfstate" "$WORK_DIR/terraform.tfstate.backup"

oci_args=()
while IFS= read -r arg; do
  [ -n "$arg" ] && oci_args+=("$arg")
done < <(oci_cli_global_args)

log_step() {
  printf '[tests] %s\n' "$*"
}

record_live_cluster_version() {
  local cluster_id="$1"
  local label="$2"
  local outfile="$ARTIFACT_DIR/live-cluster-${label}.json"
  local stderr_file="$ARTIFACT_DIR/live-cluster-${label}.stderr"

  oci ce cluster get \
    --cluster-id "$cluster_id" \
    "${oci_args[@]}" >"$outfile" 2>"$stderr_file"

  jq -r '.data."kubernetes-version" // empty' "$outfile"
}

resolve_cluster_id_from_state() {
  local state_json_file="$ARTIFACT_DIR/terraform-state-after-apply.json"
  terraform -chdir="$WORK_DIR" state pull >"$state_json_file"
  jq -r '
    first(
      .resources[]?
      | select(.mode == "managed" and .type == "oci_containerengine_cluster" and .name == "oci_oke_cluster")
      | .instances[0].attributes.id
    ) // empty
  ' "$state_json_file"
}

available_versions="$(
  oci ce cluster-options get --cluster-option-id all "${oci_args[@]}" |
    jq -r '.data."kubernetes-versions"[]' |
    sed 's/^v//' |
    sort -V
)"

if [ "$(printf '%s\n' "$available_versions" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 2 ]; then
  die "Managed cluster version drift scenario requires at least two available Kubernetes versions."
fi

upgrade_version="v$(printf '%s\n' "$available_versions" | tail -n 1)"

version_probe_log="$ARTIFACT_DIR/version-selection.txt"
: >"$version_probe_log"

initial_version=""
initial_np1_image_id=""
initial_selector_json=""
while IFS= read -r candidate_version_no_v; do
  [ -n "$candidate_version_no_v" ] || continue
  candidate_version="v${candidate_version_no_v}"
  printf '[tests] Probing worker image availability for %s\n' "$candidate_version" | tee -a "$version_probe_log"

  if TESTS_IMAGE_RESOLVER_QUIET=true TESTS_DISABLE_FIXTURE_IMAGE_OVERRIDE=true candidate_selector_json="$(resolve_oke_worker_image_selector_json "$candidate_version")"; then
    candidate_image_id="$(jq -r '.selected_image_id // empty' <<<"$candidate_selector_json")"
    candidate_source_name="$(jq -r '.selected_source_name // empty' <<<"$candidate_selector_json")"
    candidate_image_override="$(jq -r '.image_id_override // empty' <<<"$candidate_selector_json")"
    if [ -n "$candidate_image_override" ]; then
      printf '[tests] Selector unexpectedly reported image override usage for %s; trying the next lower version.\n' "$candidate_version" | tee -a "$version_probe_log"
      continue
    fi
    if [[ "$candidate_source_name" != *"-OKE-${candidate_version_no_v}-"* ]]; then
      printf '[tests] Selector returned source %s for %s; expected an OKE image tagged for %s.\n' \
        "${candidate_source_name:-unknown}" \
        "$candidate_version" \
        "$candidate_version_no_v" | tee -a "$version_probe_log"
      continue
    fi

    initial_version="$candidate_version"
    initial_np1_image_id="$candidate_image_id"
    initial_selector_json="$candidate_selector_json"
    printf '[tests] Selected initial version %s with image %s\n' "$initial_version" "$initial_np1_image_id" | tee -a "$version_probe_log"
    printf '%s\n' "$initial_selector_json" | jq '.' >"$ARTIFACT_DIR/selector-choice.json"
    break
  fi

  printf '[tests] No resolvable worker image found for %s; trying the next lower version.\n' "$candidate_version" | tee -a "$version_probe_log"
done < <(printf '%s\n' "$available_versions" | sed '$d' | sort -Vr)

require_non_empty "$initial_version" "Managed cluster version drift scenario requires at least one lower Kubernetes version with a resolvable worker image."
require_non_empty "$initial_np1_image_id" "Managed cluster version drift scenario failed to resolve an image for the selected initial version."
require_non_empty "$initial_selector_json" "Managed cluster version drift scenario failed to capture selector metadata for the selected initial version."

selector_override="$(jq -r '.image_id_override // empty' <<<"$initial_selector_json")"
selector_source_name="$(jq -r '.selected_source_name // empty' <<<"$initial_selector_json")"
selector_image_name="$(jq -r '.selected_image_name // empty' <<<"$initial_selector_json")"
if [ -n "$selector_override" ]; then
  die "Managed cluster version drift scenario must not use TF_VAR_fixture_node_image_id; selector metadata reported an override."
fi
if [[ "$selector_source_name" != *"-OKE-${initial_version#v}-"* ]]; then
  die "Selector chose source '${selector_source_name:-unknown}' for $initial_version; expected the source name to include OKE version ${initial_version#v}."
fi

printf '[tests] Selector compatibility assertion passed for %s: image=%s source=%s display_name=%s\n' \
  "$initial_version" \
  "$initial_np1_image_id" \
  "${selector_source_name:-unknown}" \
  "${selector_image_name:-unknown}" | tee -a "$version_probe_log"

export STACK_TEST_INCLUDE_IDCS_PLACEHOLDERS=false
write_managed_cluster_with_network_tfvars \
  "$WORK_DIR/terraform.tfvars" \
  "kubernetes_version = $(hcl_quote "$initial_version")" \
  "np1_image_id = $(hcl_quote "$initial_np1_image_id")"
unset STACK_TEST_INCLUDE_IDCS_PLACEHOLDERS

append_live_identity_tfvars "$WORK_DIR/terraform.tfvars"

target_args=(
  "-target=oci_containerengine_cluster.oci_oke_cluster[0]"
  "-target=terraform_data.managed_cluster_version_guard[0]"
  "-target=oci_containerengine_node_pool.oci_oke_node_pool[0]"
)

set +e
apply_output="$(
  terraform -chdir="$WORK_DIR" apply -input=false -lock=false -no-color -var-file="terraform.tfvars" "${target_args[@]}" -auto-approve 2>&1
)"
apply_status=$?
set -e

printf '%s\n' "$apply_output"

if [ "$apply_status" -ne 0 ]; then
  if [[ "$apply_output" == *"LimitExceeded"* && "$apply_output" == *"cluster limit for this tenancy has been exceeded"* ]]; then
    printf '[tests] managed-cluster drift scenario skipped: tenancy has no free OKE cluster quota for a temporary managed cluster.\n'
    exit 0
  fi
  exit "$apply_status"
fi

log_step "Resolving managed cluster id from Terraform state"
cluster_id="$(resolve_cluster_id_from_state)"
require_non_empty "$cluster_id" "Failed to resolve the managed cluster id from state."
log_step "Resolved managed cluster id: $cluster_id"

live_version_before_upgrade="$(record_live_cluster_version "$cluster_id" before-upgrade)"
require_non_empty "$live_version_before_upgrade" "Failed to read the managed cluster Kubernetes version before the manual upgrade."
log_step "Live cluster version before manual upgrade: $live_version_before_upgrade"

log_step "Manually upgrading managed cluster from $live_version_before_upgrade to $upgrade_version"
set +e
oci ce cluster update \
  --cluster-id "$cluster_id" \
  --kubernetes-version "$upgrade_version" \
  --force \
  --wait-for-state SUCCEEDED \
  "${oci_args[@]}" >"$ARTIFACT_DIR/oci-cluster-update.stdout" 2>"$ARTIFACT_DIR/oci-cluster-update.stderr"
update_status=$?
set -e
if [ "$update_status" -ne 0 ]; then
  if [ -s "$ARTIFACT_DIR/oci-cluster-update.stderr" ]; then
    sed 's/^/[tests] oci update stderr: /' "$ARTIFACT_DIR/oci-cluster-update.stderr" >&2 || true
  fi
  exit "$update_status"
fi

live_version_after_upgrade="$(record_live_cluster_version "$cluster_id" after-upgrade)"
require_non_empty "$live_version_after_upgrade" "Failed to read the managed cluster Kubernetes version after the manual upgrade."
log_step "Live cluster version after manual upgrade: $live_version_after_upgrade"
if [ "$live_version_after_upgrade" != "$upgrade_version" ]; then
  die "Manual cluster upgrade completed, but the live cluster reports Kubernetes version $live_version_after_upgrade instead of $upgrade_version."
fi

set +e
plan_output="$(
  terraform -chdir="$WORK_DIR" plan -input=false -lock=false -no-color -var-file="terraform.tfvars" "${target_args[@]}" 2>&1
)"
plan_status=$?
set -e

printf '%s\n' "$plan_output"

expected_error="The stack-managed OKE cluster is running Kubernetes version"
expected_cluster_plan_header='oci_containerengine_cluster.oci_oke_cluster[0] will be updated in-place'
expected_cluster_version_diff="kubernetes_version            = \"$upgrade_version\" -> \"$initial_version\""
if [ "$plan_status" -ne 0 ]; then
  if [[ "$plan_output" != *"$expected_error"* ]]; then
    die "Plan failed after the manual upgrade, but it did not include the managed-cluster drift guard message."
  fi
  log_step "Managed cluster drift detected via version-guard failure"
else
  if [[ "$plan_output" != *"$expected_cluster_plan_header"* ]] || [[ "$plan_output" != *"$expected_cluster_version_diff"* ]]; then
    die "Expected plan to surface manual cluster version drift, but it neither failed with the managed-cluster drift guard nor planned to reconcile the cluster from $upgrade_version back to $initial_version."
  fi
  log_step "Managed cluster drift detected via explicit reconciliation plan: $upgrade_version -> $initial_version"
fi

perl -0pi -e 's/^kubernetes_version\s*=.*$/kubernetes_version = "'"$upgrade_version"'"/m' "$WORK_DIR/terraform.tfvars"

set +e
synced_plan_output="$(
  terraform -chdir="$WORK_DIR" plan -input=false -lock=false -no-color -var-file="terraform.tfvars" "${target_args[@]}" 2>&1
)"
synced_plan_status=$?
set -e

printf '%s\n' "$synced_plan_output"

if [ "$synced_plan_status" -ne 0 ]; then
  die "Plan failed after syncing terraform.tfvars to $upgrade_version."
fi
if [[ "$synced_plan_output" == *"$expected_error"* ]]; then
  die "Managed-cluster drift guard still fired after syncing terraform.tfvars to $upgrade_version."
fi
if [[ "$synced_plan_output" == *"$expected_cluster_version_diff"* ]]; then
  die "Cluster version drift remained in the plan after syncing terraform.tfvars to $upgrade_version."
fi

printf 'managed cluster version drift guard verified: %s -> %s\n' "$initial_version" "$upgrade_version"
