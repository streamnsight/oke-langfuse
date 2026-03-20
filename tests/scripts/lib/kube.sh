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

kube_capture() {
  local stdout_file="$1"
  local stderr_file="$2"
  shift 2
  "$@" >"$stdout_file" 2>"$stderr_file" || true
}

kube_capture_api() {
  local stdout_file="$1"
  local stderr_file="$2"
  shift 2
  local request_timeout="${KUBECTL_REQUEST_TIMEOUT:-20s}"
  kubectl --request-timeout="$request_timeout" "$@" >"$stdout_file" 2>"$stderr_file" || true
}

kube_pick_context() {
  local contexts_file="$1"
  local cluster_name="$2"

  if [ -n "${KUBE_CONTEXT:-}" ]; then
    printf '%s\n' "$KUBE_CONTEXT"
    return
  fi

  if [ -n "$cluster_name" ]; then
    local named_context
    named_context="$(grep -i "$cluster_name" "$contexts_file" 2>/dev/null | head -n 1 || true)"
    if [ -n "$named_context" ]; then
      printf '%s\n' "$named_context"
      return
    fi
  fi

  head -n 1 "$contexts_file" 2>/dev/null || true
}

collect_cluster_debug() {
  local target="$1"
  local debug_dir="$2"
  local namespace="${NAMESPACE:-langfuse}"

  require_command jq
  require_command kubectl
  ensure_obc_root_dir

  local kube_dir="$debug_dir/kube"
  mkdir -p "$kube_dir/describes" "$kube_dir/logs"

  local outputs_json stack_outputs
  outputs_json="$(load_fixture_outputs "$target")"
  stack_outputs="$(root_stack_outputs_json)"

  printf '%s\n' "$outputs_json" >"$kube_dir/fixture-outputs.json"
  printf '%s\n' "$stack_outputs" >"$kube_dir/root-stack-outputs.json"

  local cluster_id cluster_name bastion_id
  cluster_id="$(printf '%s\n' "$outputs_json" | jq -r 'try .cluster_id.value // empty')"
  cluster_name="$(printf '%s\n' "$outputs_json" | jq -r 'try .cluster_name.value // empty')"
  bastion_id="$(printf '%s\n' "$outputs_json" | jq -r 'try .bastion_id.value // empty')"

  if [ -z "$cluster_id" ]; then
    cluster_id="$(printf '%s\n' "$stack_outputs" | jq -r 'try .test_metadata.value.cluster.id // empty')"
  fi
  if [ -z "$cluster_name" ]; then
    cluster_name="$(printf '%s\n' "$stack_outputs" | jq -r 'try .test_metadata.value.cluster.name // empty')"
  fi
  if [ -z "$bastion_id" ]; then
    bastion_id="$(printf '%s\n' "$stack_outputs" | jq -r 'try .test_metadata.value.bastion.id // empty')"
  fi

  jq -n \
    --arg target "$target" \
    --arg namespace "$namespace" \
    --arg cluster_id "$cluster_id" \
    --arg cluster_name "$cluster_name" \
    --arg bastion_id "$bastion_id" \
    --arg obc_root_dir "${OBC_ROOT_DIR:-}" '
      {
        target: $target,
        namespace: $namespace,
        cluster_id: $cluster_id,
        cluster_name: $cluster_name,
        bastion_id: $bastion_id,
        obc_root_dir: $obc_root_dir
      }
    ' >"$kube_dir/request.json"

  if [ -n "$cluster_id" ] && [ -n "${OCI_PROFILE:-}" ] && command -v obc >/dev/null 2>&1; then
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

  kube_capture "$kube_dir/contexts-before.txt" "$kube_dir/contexts-before.stderr" kubectl config get-contexts -o name
  kube_capture "$kube_dir/contexts-after.txt" "$kube_dir/contexts-after.stderr" kubectl config get-contexts -o name

  local selected_context
  selected_context="$(kube_pick_context "$kube_dir/contexts-after.txt" "$cluster_name")"
  if [ -n "$selected_context" ]; then
    kube_capture "$kube_dir/use-context.stdout" "$kube_dir/use-context.stderr" kubectl config use-context "$selected_context"
  fi

  kube_capture "$kube_dir/current-context.txt" "$kube_dir/current-context.stderr" kubectl config current-context
  kube_capture_api "$kube_dir/cluster-info.txt" "$kube_dir/cluster-info.stderr" cluster-info
  if [ -s "$kube_dir/cluster-info.stderr" ]; then
    return 0
  fi
  kube_capture_api "$kube_dir/namespaces.txt" "$kube_dir/namespaces.stderr" get ns
  kube_capture_api "$kube_dir/resources.txt" "$kube_dir/resources.stderr" get all -n "$namespace" -o wide
  kube_capture_api "$kube_dir/workloads.txt" "$kube_dir/workloads.stderr" get deploy,sts,ds,job,cronjob -n "$namespace" -o wide
  kube_capture_api "$kube_dir/services.txt" "$kube_dir/services.stderr" get svc -n "$namespace" -o wide
  kube_capture_api "$kube_dir/pods.json" "$kube_dir/pods.stderr" get pods -n "$namespace" -o json
  kube_capture_api "$kube_dir/pods.txt" "$kube_dir/pods-wide.stderr" get pods -n "$namespace" -o wide
  kube_capture_api "$kube_dir/events.txt" "$kube_dir/events.stderr" get events -n "$namespace" --sort-by=.metadata.creationTimestamp

  local pod_name
  while IFS= read -r pod_name; do
    [ -n "$pod_name" ] || continue
    kube_capture_api \
      "$kube_dir/describes/$(slugify "$pod_name").txt" \
      "$kube_dir/describes/$(slugify "$pod_name").stderr" \
      describe pod "$pod_name" -n "$namespace"

    kube_capture_api \
      "$kube_dir/logs/$(slugify "$pod_name").log" \
      "$kube_dir/logs/$(slugify "$pod_name").stderr" \
      logs "$pod_name" -n "$namespace" --all-containers=true --tail=500

    kube_capture_api \
      "$kube_dir/logs/$(slugify "$pod_name")-previous.log" \
      "$kube_dir/logs/$(slugify "$pod_name")-previous.stderr" \
      logs "$pod_name" -n "$namespace" --all-containers=true --previous --tail=500
  done < <(jq -r 'try .items // [] | .[] | .metadata.name' "$kube_dir/pods.json" 2>/dev/null)
}
