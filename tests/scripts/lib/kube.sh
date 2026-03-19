#!/usr/bin/env bash

load_fixture_outputs() {
  local target="$1"
  local fixture_dir
  fixture_dir="$(fixture_dir_for_target "$target")"
  if [ -f "$fixture_dir/terraform.tfstate" ]; then
    terraform -chdir="$fixture_dir" output -json 2>/dev/null || printf '{}\n'
  else
    printf '{}\n'
  fi
}

collect_cluster_debug() {
  local target="$1"
  local debug_dir="$2"
  local namespace="${NAMESPACE:-langfuse}"

  require_command jq
  require_command kubectl

  local kube_dir="$debug_dir/kube"
  mkdir -p "$kube_dir"

  local outputs_json
  outputs_json="$(load_fixture_outputs "$target")"
  printf '%s\n' "$outputs_json" >"$kube_dir/fixture-outputs.json"

  local stack_outputs
  stack_outputs="$(root_stack_outputs_json)"
  printf '%s\n' "$stack_outputs" >"$kube_dir/root-stack-outputs.json"

  local cluster_id bastion_id
  cluster_id="$(printf '%s\n' "$outputs_json" | jq -r 'try .cluster_id.value // empty')"
  bastion_id="$(printf '%s\n' "$outputs_json" | jq -r 'try .bastion_id.value // empty')"

  if [ -z "$cluster_id" ]; then
    cluster_id="$(printf '%s\n' "$stack_outputs" | jq -r 'try .test_metadata.value.cluster.id // empty')"
  fi
  if [ -z "$bastion_id" ]; then
    bastion_id="$(printf '%s\n' "$stack_outputs" | jq -r 'try .test_metadata.value.bastion.id // empty')"
  fi

  if [ -n "$cluster_id" ] && [ -n "${OCI_PROFILE:-}" ]; then
    if command -v obc >/dev/null 2>&1; then
      local obc_args=(
        registry oke add
        --auth-profile "$OCI_PROFILE"
        --cluster-id "$cluster_id"
      )
      if [ -n "$bastion_id" ]; then
        obc_args+=(--bastion-id "$bastion_id")
      fi
      obc "${obc_args[@]}" >"$kube_dir/obc-registry.stdout" 2>"$kube_dir/obc-registry.stderr" || true
    fi
  fi

  kubectl config current-context >"$kube_dir/current-context.txt" 2>"$kube_dir/current-context.stderr" || true
  kubectl get ns >"$kube_dir/namespaces.txt" 2>"$kube_dir/namespaces.stderr" || true
  kubectl get pods -n "$namespace" -o wide >"$kube_dir/pods.txt" 2>"$kube_dir/pods.stderr" || true
  kubectl get events -n "$namespace" --sort-by=.metadata.creationTimestamp >"$kube_dir/events.txt" 2>"$kube_dir/events.stderr" || true
}
