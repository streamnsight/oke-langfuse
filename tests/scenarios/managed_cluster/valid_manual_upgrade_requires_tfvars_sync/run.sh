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

require_command jq
require_command oci

assert_network_fixture_ready

rm -f "$WORK_DIR/terraform.tfstate" "$WORK_DIR/terraform.tfstate.backup"

oci_args=()
while IFS= read -r arg; do
  [ -n "$arg" ] && oci_args+=("$arg")
done < <(oci_cli_global_args)

available_versions="$(
  oci ce cluster-options get --cluster-option-id all "${oci_args[@]}" |
    jq -r '.data."kubernetes-versions"[]' |
    sed 's/^v//' |
    sort -V
)"

if [ "$(printf '%s\n' "$available_versions" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 2 ]; then
  die "Managed cluster version drift scenario requires at least two available Kubernetes versions."
fi

initial_version="v$(printf '%s\n' "$available_versions" | tail -n 2 | head -n 1)"
upgrade_version="v$(printf '%s\n' "$available_versions" | tail -n 1)"

write_managed_cluster_with_network_tfvars \
  "$WORK_DIR/terraform.tfvars" \
  "kubernetes_version = $(hcl_quote "$initial_version")"

target_args=(
  "-target=oci_containerengine_cluster.oci_oke_cluster[0]"
  "-target=terraform_data.managed_cluster_version_guard[0]"
  "-target=oci_containerengine_node_pool.oci_oke_node_pool[0]"
)

terraform -chdir="$WORK_DIR" apply -input=false -lock=false -no-color -var-file="terraform.tfvars" "${target_args[@]}" -auto-approve >/dev/null

cluster_id="$(
  terraform -chdir="$WORK_DIR" show -json |
    jq -r '.values.root_module.resources[] | select(.address=="oci_containerengine_cluster.oci_oke_cluster[0]").values.id'
)"
require_non_empty "$cluster_id" "Failed to resolve the managed cluster id from state."

oci ce cluster update \
  --cluster-id "$cluster_id" \
  --kubernetes-version "$upgrade_version" \
  --force \
  --wait-for-state ACTIVE \
  "${oci_args[@]}" >/dev/null

set +e
plan_output="$(
  terraform -chdir="$WORK_DIR" plan -input=false -lock=false -no-color -var-file="terraform.tfvars" "${target_args[@]}" 2>&1
)"
plan_status=$?
set -e

printf '%s\n' "$plan_output"

if [ "$plan_status" -eq 0 ]; then
  die "Expected plan to fail after the out-of-band cluster upgrade, but it succeeded."
fi

expected_error="The stack-managed OKE cluster is running Kubernetes version"
if [[ "$plan_output" != *"$expected_error"* ]]; then
  die "Plan failed after the manual upgrade, but it did not include the managed-cluster drift guard message."
fi

perl -0pi -e 's/^kubernetes_version\s*=.*$/kubernetes_version = "'"$upgrade_version"'"/m' "$WORK_DIR/terraform.tfvars"

terraform -chdir="$WORK_DIR" plan -input=false -lock=false -no-color -var-file="terraform.tfvars" "${target_args[@]}" >/dev/null

printf 'managed cluster version drift guard verified: %s -> %s\n' "$initial_version" "$upgrade_version"
