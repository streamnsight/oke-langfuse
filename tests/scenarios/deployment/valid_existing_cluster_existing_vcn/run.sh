#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${1:?workdir is required}"
ARTIFACT_DIR="${TESTS_SCENARIO_ARTIFACT_DIR:-$WORK_DIR/tests/artifacts/full-stack-validation}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
export ROOT_TERRAFORM_STATE_FILE="$WORK_DIR/terraform.tfstate"
# shellcheck source=tests/scripts/lib/common.sh
source "$TESTS_DIR/scripts/lib/common.sh"
# shellcheck source=tests/scripts/lib/fixtures.sh
source "$TESTS_DIR/scripts/lib/fixtures.sh"
# shellcheck source=tests/scripts/lib/scenarios.sh
source "$TESTS_DIR/scripts/lib/scenarios.sh"
# shellcheck source=tests/scripts/lib/devops.sh
source "$TESTS_DIR/scripts/lib/devops.sh"
# shellcheck source=tests/scripts/lib/kube.sh
source "$TESTS_DIR/scripts/lib/kube.sh"

require_command terraform
require_command jq
require_command oci
require_command kubectl
require_command curl
require_command obc

mkdir -p "$ARTIFACT_DIR/validators"

oci_args=()
while IFS= read -r arg; do
  [ -n "$arg" ] && oci_args+=("$arg")
done < <(oci_cli_global_args)

VALIDATION_NAMES=()
VALIDATION_STATUSES=()
VALIDATION_MESSAGES=()
VALIDATION_FAILURES=()
METADATA_READY="false"
KUBE_CONTEXT_READY="false"

record_validation() {
  local name="$1"
  local status="$2"
  local message="$3"

  VALIDATION_NAMES+=("$name")
  VALIDATION_STATUSES+=("$status")
  VALIDATION_MESSAGES+=("$message")

  if [ "$status" = "FAIL" ]; then
    VALIDATION_FAILURES+=("$name: $message")
  fi

  printf '[tests] validation %s %s: %s\n' "$status" "$name" "$message"
}

write_summary() {
  local summary_file="$ARTIFACT_DIR/validation-summary.txt"
  : >"$summary_file"

  printf 'Full Stack Validation Summary\n' >>"$summary_file"
  printf '=============================\n' >>"$summary_file"

  local i
  for ((i = 0; i < ${#VALIDATION_NAMES[@]}; i++)); do
    printf '%s %s: %s\n' \
      "${VALIDATION_STATUSES[$i]}" \
      "${VALIDATION_NAMES[$i]}" \
      "${VALIDATION_MESSAGES[$i]}" >>"$summary_file"
  done

  if [ "${#VALIDATION_FAILURES[@]}" -gt 0 ]; then
    printf '\nFailures\n' >>"$summary_file"
    printf '--------\n' >>"$summary_file"
    local failure
    for failure in "${VALIDATION_FAILURES[@]}"; do
      printf '%s\n' "$failure" >>"$summary_file"
    done
  fi

  cat "$summary_file"
}

capture_outputs() {
  terraform -chdir="$WORK_DIR" output -json >"$ARTIFACT_DIR/terraform-outputs.json"
  jq '.test_metadata.value // {}' "$ARTIFACT_DIR/terraform-outputs.json" >"$ARTIFACT_DIR/test-metadata.json"
}

metadata_value() {
  local jq_filter="$1"
  jq -r "$jq_filter // empty" "$ARTIFACT_DIR/test-metadata.json"
}

retry_with_backoff() {
  local attempts="$1"
  local sleep_seconds="$2"
  shift 2

  local attempt=1
  while [ "$attempt" -le "$attempts" ]; do
    if "$@"; then
      return 0
    fi
    if [ "$attempt" -lt "$attempts" ]; then
      sleep "$sleep_seconds"
    fi
    attempt=$((attempt + 1))
  done

  return 1
}

prepare_kube_context() {
  if [ "$KUBE_CONTEXT_READY" = "true" ]; then
    return 0
  fi

  local kube_dir="$ARTIFACT_DIR/kube-validation"
  mkdir -p "$kube_dir"

  local fixture_outputs
  fixture_outputs="$(load_fixture_outputs enhanced)"
  printf '%s\n' "$fixture_outputs" >"$kube_dir/fixture-outputs.json"

  local cluster_id cluster_name bastion_id
  cluster_id="$(metadata_value '.cluster.id')"
  cluster_name="$(metadata_value '.cluster.name')"
  bastion_id="$(printf '%s\n' "$fixture_outputs" | jq -r 'try .bastion_id.value // empty')"

  if [ -z "$cluster_id" ]; then
    cluster_id="$(printf '%s\n' "$fixture_outputs" | jq -r 'try .cluster_id.value // empty')"
  fi
  if [ -z "$cluster_name" ]; then
    cluster_name="$(printf '%s\n' "$fixture_outputs" | jq -r 'try .cluster_name.value // empty')"
  fi

  if [ -z "$cluster_id" ]; then
    return 1
  fi

  ensure_obc_root_dir

  local obc_args=(
    registry oke add
    --auth-profile "$OCI_PROFILE"
    --cluster-id "$cluster_id"
  )
  if [ -n "$bastion_id" ]; then
    obc_args+=(--bastion-id "$bastion_id")
  fi
  obc "${obc_args[@]}" >"$kube_dir/obc-registry.stdout" 2>"$kube_dir/obc-registry.stderr"

  kubectl config get-contexts -o name >"$kube_dir/contexts.txt"
  local selected_context
  selected_context="$(kube_pick_context "$kube_dir/contexts.txt" "$cluster_name")"
  if [ -z "$selected_context" ]; then
    return 1
  fi
  kubectl config use-context "$selected_context" >"$kube_dir/use-context.stdout" 2>"$kube_dir/use-context.stderr"

  KUBE_CONTEXT_READY="true"
}

collect_runtime_debug() {
  local debug_dir="$ARTIFACT_DIR/runtime-debug"
  mkdir -p "$debug_dir"

  log "Collecting runtime debug artifacts into $debug_dir"
  collect_devops_debug enhanced "$debug_dir" || true
  collect_cluster_debug enhanced "$debug_dir" || true
}

validate_test_metadata() {
  local missing=()
  local required_paths=(
    '.cluster.id'
    '.cluster.name'
    '.deployment.deploy_id'
    '.deployment.namespace'
    '.deployment.langfuse_url'
    '.gateway.load_balancer_id'
    '.gateway.ip_address'
    '.devops.project_id'
    '.devops.deployment_ids.builder_setup'
    '.devops.deployment_ids.build_langfuse_image'
    '.devops.deployment_ids.langfuse_gateway'
    '.devops.deployment_ids.langfuse_chart'
    '.registry.compartment_id'
    '.registry.tenancy_namespace'
    '.registry.repositories.langfuse'
    '.vulnerability_scanning.recipe_id'
    '.vulnerability_scanning.target_id'
  )
  local path
  for path in "${required_paths[@]}"; do
    if [ -z "$(metadata_value "$path")" ]; then
      missing+=("$path")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    record_validation "test-metadata" "FAIL" "Missing required metadata fields: ${missing[*]}"
    return 1
  fi

  METADATA_READY="true"
  record_validation "test-metadata" "PASS" "Required runtime metadata is present."
  return 0
}

validate_load_balancer() {
  if [ "$METADATA_READY" != "true" ]; then
    record_validation "langfuse-load-balancer" "FAIL" "Skipped OCI lookup because test metadata is unavailable."
    return 1
  fi

  local lb_id expected_ip lb_file lb_stderr
  lb_id="$(metadata_value '.gateway.load_balancer_id')"
  expected_ip="$(metadata_value '.gateway.ip_address')"
  lb_file="$ARTIFACT_DIR/validators/langfuse-load-balancer.json"
  lb_stderr="$ARTIFACT_DIR/validators/langfuse-load-balancer.stderr"

  validate_lb_once() {
    oci "${oci_args[@]}" lb load-balancer get --load-balancer-id "$lb_id" >"$lb_file" 2>"$lb_stderr" || return 1

    local lifecycle_state observed_ip
    lifecycle_state="$(jq -r 'try (.data."lifecycle-state" // .data.lifecycleState // .data.lifecycle_state) // empty' "$lb_file")"
    observed_ip="$(jq -r 'try (.data."ip-addresses"[0]."ip-address" // .data.ipAddresses[0].ipAddress // .data.ip_addresses[0].ip_address) // empty' "$lb_file")"

    [ "$lifecycle_state" = "ACTIVE" ] || return 1
    [ "$observed_ip" = "$expected_ip" ] || return 1
  }

  if retry_with_backoff 20 15 validate_lb_once; then
    record_validation "langfuse-load-balancer" "PASS" "Load balancer $lb_id is ACTIVE at $expected_ip."
    return 0
  fi

  local last_state last_ip
  last_state="$(jq -r 'try (.data."lifecycle-state" // .data.lifecycleState // .data.lifecycle_state) // "unknown"' "$lb_file" 2>/dev/null || printf 'unknown\n')"
  last_ip="$(jq -r 'try (.data."ip-addresses"[0]."ip-address" // .data.ipAddresses[0].ipAddress // .data.ip_addresses[0].ip_address) // "unknown"' "$lb_file" 2>/dev/null || printf 'unknown\n')"
  record_validation "langfuse-load-balancer" "FAIL" "Expected ACTIVE load balancer $lb_id at $expected_ip, last state=$last_state ip=$last_ip."
  return 1
}

validate_devops_deployments() {
  if [ "$METADATA_READY" != "true" ]; then
    record_validation "devops-deployments" "FAIL" "Skipped DevOps checks because test metadata is unavailable."
    return 1
  fi

  local required_deployments=(
    builder_setup
    build_langfuse_image
    langfuse_gateway
    langfuse_chart
  )
  local failures=()
  local deployment_name

  wait_for_deployment_success() {
    local deployment_id="$1"
    local output_file="$2"
    local stderr_file="$3"

    wait_for_deployment_success_once() {
      oci "${oci_args[@]}" devops deployment get --deployment-id "$deployment_id" >"$output_file" 2>"$stderr_file" || return 1
      local lifecycle_state
      lifecycle_state="$(jq -r 'try (.data."lifecycle-state" // .data.lifecycleState // .data.lifecycle_state) // empty' "$output_file")"
      [ "$lifecycle_state" = "SUCCEEDED" ]
    }

    retry_with_backoff 20 15 wait_for_deployment_success_once
  }

  for deployment_name in "${required_deployments[@]}"; do
    local deployment_id deployment_file deployment_stderr lifecycle_state
    deployment_id="$(metadata_value ".devops.deployment_ids.$deployment_name")"
    if [ -z "$deployment_id" ]; then
      failures+=("$deployment_name missing deployment id")
      continue
    fi

    deployment_file="$ARTIFACT_DIR/validators/devops-${deployment_name}.json"
    deployment_stderr="$ARTIFACT_DIR/validators/devops-${deployment_name}.stderr"
    if ! wait_for_deployment_success "$deployment_id" "$deployment_file" "$deployment_stderr"; then
      lifecycle_state="$(jq -r 'try (.data."lifecycle-state" // .data.lifecycleState // .data.lifecycle_state) // "unknown"' "$deployment_file" 2>/dev/null || printf 'unknown\n')"
      failures+=("$deployment_name state=$lifecycle_state")
    fi
  done

  if [ "${#failures[@]}" -gt 0 ]; then
    record_validation "devops-deployments" "FAIL" "Required deployments not healthy: ${failures[*]}"
    return 1
  fi

  record_validation "devops-deployments" "PASS" "Required DevOps deployments completed successfully."
  return 0
}

validate_registry_images() {
  if [ "$METADATA_READY" != "true" ]; then
    record_validation "container-registry" "FAIL" "Skipped registry checks because test metadata is unavailable."
    return 1
  fi

  local compartment_id repository_list_file repository_list_stderr
  compartment_id="$(metadata_value '.registry.compartment_id')"
  repository_list_file="$ARTIFACT_DIR/validators/registry-repositories.json"
  repository_list_stderr="$ARTIFACT_DIR/validators/registry-repositories.stderr"

  if ! oci "${oci_args[@]}" artifacts container repository list \
    --compartment-id "$compartment_id" \
    --all >"$repository_list_file" 2>"$repository_list_stderr"; then
    record_validation "container-registry" "FAIL" "Failed to list OCIR repositories in compartment $compartment_id."
    return 1
  fi

  local repo_keys=(
    langfuse
    oci_genai_gateway
  )
  local failures=()
  local skipped=()
  local repo_key
  for repo_key in "${repo_keys[@]}"; do
    local repo_name repo_id images_file images_stderr image_count
    repo_name="$(metadata_value ".registry.repositories.$repo_key")"
    if [ -z "$repo_name" ]; then
      skipped+=("$repo_key")
      continue
    fi

    repo_id="$(jq -r --arg repo_name "$repo_name" '
      try .data.items // [] |
      map(select((."display-name" // .displayName // "") == $repo_name)) |
      .[0].id // empty
    ' "$repository_list_file")"
    if [ -z "$repo_id" ]; then
      failures+=("$repo_key repository missing")
      continue
    fi

    images_file="$ARTIFACT_DIR/validators/registry-${repo_key}-images.json"
    images_stderr="$ARTIFACT_DIR/validators/registry-${repo_key}-images.stderr"
    if ! oci "${oci_args[@]}" artifacts container image list \
      --compartment-id "$compartment_id" \
      --repository-id "$repo_id" \
      --all >"$images_file" 2>"$images_stderr"; then
      failures+=("$repo_key image lookup failed")
      continue
    fi

    image_count="$(jq -r 'try (.data.items | length) // 0' "$images_file")"
    if [ "$image_count" -lt 1 ]; then
      failures+=("$repo_key has no pushed images")
    fi
  done

  if [ "${#failures[@]}" -gt 0 ]; then
    record_validation "container-registry" "FAIL" "Registry validation failed: ${failures[*]}"
    return 1
  fi

  if [ "${#skipped[@]}" -gt 0 ]; then
    record_validation "container-registry" "PASS" "Required repos contain images. Optional repos skipped: ${skipped[*]}"
  else
    record_validation "container-registry" "PASS" "Required repos contain pushed images."
  fi
  return 0
}

validate_vulnerability_scanning() {
  if [ "$METADATA_READY" != "true" ]; then
    record_validation "vulnerability-scanning" "FAIL" "Skipped vulnerability scanning checks because test metadata is unavailable."
    return 1
  fi

  local recipe_id target_id recipe_file recipe_stderr target_file target_stderr
  recipe_id="$(metadata_value '.vulnerability_scanning.recipe_id')"
  target_id="$(metadata_value '.vulnerability_scanning.target_id')"
  recipe_file="$ARTIFACT_DIR/validators/vulnerability-scan-recipe.json"
  recipe_stderr="$ARTIFACT_DIR/validators/vulnerability-scan-recipe.stderr"
  target_file="$ARTIFACT_DIR/validators/vulnerability-scan-target.json"
  target_stderr="$ARTIFACT_DIR/validators/vulnerability-scan-target.stderr"

  if ! oci "${oci_args[@]}" vulnerability-scanning container scan recipe get \
    --container-scan-recipe-id "$recipe_id" >"$recipe_file" 2>"$recipe_stderr"; then
    record_validation "vulnerability-scanning" "FAIL" "Failed to fetch scan recipe $recipe_id."
    return 1
  fi

  wait_for_scan_target_once() {
    oci "${oci_args[@]}" vulnerability-scanning container scan target get \
      --container-scan-target-id "$target_id" >"$target_file" 2>"$target_stderr" || return 1

    local target_repositories
    target_repositories="$(jq -r '
      [
        try (
          .data."target-registry".repositories
          // .data.targetRegistry.repositories
          // .data.target_registry.repositories
          // []
        )[]
      ] | @tsv
    ' "$target_file")"

    local expected_repo
    while IFS= read -r expected_repo; do
      [ -n "$expected_repo" ] || continue
      if ! printf '%s\n' "$target_repositories" | tr '\t' '\n' | grep -Fxq "$expected_repo"; then
        return 1
      fi
    done < <(jq -r '.vulnerability_scanning.repositories[]?' "$ARTIFACT_DIR/test-metadata.json")
  }

  if ! retry_with_backoff 20 15 wait_for_scan_target_once; then
    record_validation "vulnerability-scanning" "FAIL" "Scan target $target_id did not expose the expected repositories."
    return 1
  fi

  record_validation "vulnerability-scanning" "PASS" "Vulnerability scanning recipe and target include the expected repositories."
  return 0
}

validate_kubernetes_workloads() {
  if [ "$METADATA_READY" != "true" ]; then
    record_validation "kubernetes-workloads" "FAIL" "Skipped Kubernetes checks because test metadata is unavailable."
    return 1
  fi

  local namespace kube_dir
  namespace="$(metadata_value '.deployment.namespace')"
  kube_dir="$ARTIFACT_DIR/validators/kubernetes"
  mkdir -p "$kube_dir"

  if ! prepare_kube_context; then
    record_validation "kubernetes-workloads" "FAIL" "Failed to prepare kubectl context."
    return 1
  fi

  validate_kubernetes_once() {
    kubectl get namespace "$namespace" -o json >"$kube_dir/namespace.json" 2>"$kube_dir/namespace.stderr" || return 1
    kubectl get deploy -n "$namespace" -o json >"$kube_dir/deployments.json" 2>"$kube_dir/deployments.stderr" || return 1
    kubectl get sts -n "$namespace" -o json >"$kube_dir/statefulsets.json" 2>"$kube_dir/statefulsets.stderr" || return 1
    kubectl get svc -n "$namespace" -o json >"$kube_dir/services.json" 2>"$kube_dir/services.stderr" || return 1

    local deployment_total deployment_ready statefulset_total statefulset_ready service_total
    deployment_total="$(jq -r '(.items // []) | length' "$kube_dir/deployments.json")"
    deployment_ready="$(jq -r '
      [
        (.items // [])[] |
        select(((.status.readyReplicas // 0) | tonumber) >= ((.spec.replicas // 0) | tonumber))
      ] | length
    ' "$kube_dir/deployments.json")"
    statefulset_total="$(jq -r '(.items // []) | length' "$kube_dir/statefulsets.json")"
    statefulset_ready="$(jq -r '
      [
        (.items // [])[] |
        select(((.status.readyReplicas // 0) | tonumber) >= ((.spec.replicas // 0) | tonumber))
      ] | length
    ' "$kube_dir/statefulsets.json")"
    service_total="$(jq -r '(.items // []) | length' "$kube_dir/services.json")"

    if [ $((deployment_total + statefulset_total)) -lt 1 ]; then
      return 1
    fi
    if [ "$deployment_ready" -lt "$deployment_total" ]; then
      return 1
    fi
    if [ "$statefulset_ready" -lt "$statefulset_total" ]; then
      return 1
    fi
    if [ "$service_total" -lt 1 ]; then
      return 1
    fi
  }

  if retry_with_backoff 20 15 validate_kubernetes_once; then
    record_validation "kubernetes-workloads" "PASS" "Langfuse namespace, workloads, and services are ready."
    return 0
  fi

  record_validation "kubernetes-workloads" "FAIL" "Langfuse namespace/workloads/services did not reach readiness."
  return 1
}

validate_langfuse_endpoint() {
  if [ "$METADATA_READY" != "true" ]; then
    record_validation "langfuse-endpoint" "FAIL" "Skipped endpoint check because test metadata is unavailable."
    return 1
  fi

  local langfuse_url endpoint_dir
  langfuse_url="$(metadata_value '.deployment.langfuse_url')"
  endpoint_dir="$ARTIFACT_DIR/validators/langfuse-endpoint"
  mkdir -p "$endpoint_dir"

  validate_endpoint_once() {
    local status_code
    status_code="$(
      curl \
        --insecure \
        --silent \
        --show-error \
        --location \
        --max-time 30 \
        --output "$endpoint_dir/body.html" \
        --write-out '%{http_code}' \
        "$langfuse_url" 2>"$endpoint_dir/curl.stderr"
    )" || return 1

    printf '%s\n' "$status_code" >"$endpoint_dir/status-code.txt"
    case "$status_code" in
      2*|3*)
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  }

  if retry_with_backoff 20 15 validate_endpoint_once; then
    record_validation "langfuse-endpoint" "PASS" "Langfuse endpoint responded successfully at $langfuse_url."
    return 0
  fi

  local last_status
  last_status="$(cat "$endpoint_dir/status-code.txt" 2>/dev/null || printf 'unknown\n')"
  record_validation "langfuse-endpoint" "FAIL" "Langfuse endpoint did not return success. Last status: $last_status"
  return 1
}

printf '[tests] Applying the full stack once for post-deploy validation\n'
set +e
terraform -chdir="$WORK_DIR" apply -input=false -lock=false -no-color -var-file="terraform.tfvars" -auto-approve
apply_status=$?
set -e

if [ "$apply_status" -ne 0 ]; then
  if [ -f "$WORK_DIR/terraform.tfstate" ]; then
    capture_outputs || true
    collect_runtime_debug
  fi
  exit "$apply_status"
fi

capture_outputs

validate_test_metadata || true
validate_load_balancer || true
validate_devops_deployments || true
validate_registry_images || true
validate_vulnerability_scanning || true
validate_kubernetes_workloads || true
validate_langfuse_endpoint || true

write_summary

if [ "${#VALIDATION_FAILURES[@]}" -gt 0 ]; then
  collect_runtime_debug
  exit 1
fi
