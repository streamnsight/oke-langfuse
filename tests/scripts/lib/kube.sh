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

kube_write_pod_summary() {
  local pods_json="$1"
  local summary_file="$2"

  if [ ! -f "$pods_json" ]; then
    return 0
  fi

  jq -r '
    def container_state_reason:
      .state.waiting.reason
      // .state.terminated.reason
      // .lastState.terminated.reason
      // "";
    def container_state_message:
      .state.waiting.message
      // .state.terminated.message
      // .lastState.terminated.message
      // "";

    if ((.items // []) | length) == 0 then
      "Pods",
      "----",
      "- none discovered"
    else
      "Pods",
      "----",
      (
        (.items // [])[] |
        "- " + (.metadata.name // "unknown"),
        "  phase=" + (.status.phase // "unknown"),
        "  node=" + (.spec.nodeName // "unassigned"),
        "  pod_ip=" + (.status.podIP // "unknown"),
        "  conditions=" + (
          [
            (.status.conditions // [])[]? |
            select((.status // "") != "True") |
            (.type // "unknown") + ":" + (.status // "unknown")
          ] | if length == 0 then "ready" else join(", ") end
        ),
        (
          [
            (.status.initContainerStatuses // [])[]?,
            (.status.containerStatuses // [])[]?
          ] |
          if length == 0 then
            "  containers=none"
          else
            .[] |
            "  container=" + (.name // "unknown")
            + " ready=" + ((.ready // false) | tostring)
            + " restarts=" + ((.restartCount // 0) | tostring)
            + " image=" + (.image // "unknown")
            + (
              if (container_state_reason | length) > 0 then
                " reason=" + container_state_reason
              else
                ""
              end
            )
            + (
              if (container_state_message | length) > 0 then
                " message=" + (container_state_message | gsub("[\r\n\t]+"; " "))
              else
                ""
              end
            )
          end
        )
      )
    end
  ' "$pods_json" >"$summary_file" 2>/dev/null || true
}

kube_append_warning_events_summary() {
  local events_file="$1"
  local summary_file="$2"

  if [ ! -f "$events_file" ]; then
    return 0
  fi

  {
    printf '\nWarning Events\n'
    printf '--------------\n'
    if ! awk 'NR == 1 {next} /Warning|Failed|BackOff|ErrImagePull|ImagePullBackOff|FailedScheduling|FailedMount/ {print}' "$events_file"; then
      :
    fi
  } >>"$summary_file"
}

kube_append_node_summary() {
  local nodes_json="$1"
  local summary_file="$2"

  if [ ! -f "$nodes_json" ]; then
    return 0
  fi

  {
    printf '\nNodes\n'
    printf '-----\n'
    jq -r '
      if ((.items // []) | length) == 0 then
        "- none discovered"
      else
        (.items // [])[] |
        "- " + (.metadata.name // "unknown")
        + " ready="
        + (
          [
            (.status.conditions // [])[]? |
            select((.type // "") == "Ready") |
            (.status // "unknown")
          ][0] // "unknown"
        )
        + " schedulable="
        + (if (.spec.unschedulable // false) then "false" else "true" end)
        + " internal_ip="
        + (
          [
            (.status.addresses // [])[]? |
            select((.type // "") == "InternalIP") |
            (.address // "unknown")
          ][0] // "unknown"
        )
      end
    ' "$nodes_json" 2>/dev/null || printf '%s\n' '- unavailable'
  } >>"$summary_file"
}

collect_cluster_debug() {
  local target="$1"
  local debug_dir="$2"
  local namespace="${NAMESPACE:-langfuse}"

  require_command jq
  require_command kubectl
  ensure_obc_root_dir

  local kube_dir="$debug_dir/kube"
  mkdir -p "$kube_dir/describes" "$kube_dir/logs" "$kube_dir/node-describes" "$kube_dir/pod-yaml"

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
  kube_capture_api "$kube_dir/nodes.json" "$kube_dir/nodes.stderr" get nodes -o json
  kube_capture_api "$kube_dir/nodes.txt" "$kube_dir/nodes-wide.stderr" get nodes -o wide
  kube_capture_api "$kube_dir/cluster-events.txt" "$kube_dir/cluster-events.stderr" get events -A --sort-by=.metadata.creationTimestamp
  kube_capture_api "$kube_dir/namespaces.txt" "$kube_dir/namespaces.stderr" get ns
  kube_capture_api "$kube_dir/resources.txt" "$kube_dir/resources.stderr" get all -n "$namespace" -o wide
  kube_capture_api "$kube_dir/workloads.txt" "$kube_dir/workloads.stderr" get deploy,sts,ds,job,cronjob -n "$namespace" -o wide
  kube_capture_api "$kube_dir/workloads.json" "$kube_dir/workloads-json.stderr" get deploy,sts,ds,job,cronjob,rs -n "$namespace" -o json
  kube_capture_api "$kube_dir/services.txt" "$kube_dir/services.stderr" get svc -n "$namespace" -o wide
  kube_capture_api "$kube_dir/services.json" "$kube_dir/services-json.stderr" get svc,endpoints,ingress,pvc -n "$namespace" -o json
  kube_capture_api "$kube_dir/pods.json" "$kube_dir/pods.stderr" get pods -n "$namespace" -o json
  kube_capture_api "$kube_dir/pods.txt" "$kube_dir/pods-wide.stderr" get pods -n "$namespace" -o wide
  kube_capture_api "$kube_dir/events.txt" "$kube_dir/events.stderr" get events -n "$namespace" --sort-by=.metadata.creationTimestamp
  kube_write_pod_summary "$kube_dir/pods.json" "$kube_dir/summary.txt"
  kube_append_node_summary "$kube_dir/nodes.json" "$kube_dir/summary.txt"
  kube_append_warning_events_summary "$kube_dir/events.txt" "$kube_dir/summary.txt"
  kube_append_warning_events_summary "$kube_dir/cluster-events.txt" "$kube_dir/summary.txt"

  local node_name
  while IFS= read -r node_name; do
    [ -n "$node_name" ] || continue
    kube_capture_api \
      "$kube_dir/node-describes/$(slugify "$node_name").txt" \
      "$kube_dir/node-describes/$(slugify "$node_name").stderr" \
      describe node "$node_name"
  done < <(jq -r 'try .items // [] | .[] | .metadata.name' "$kube_dir/nodes.json" 2>/dev/null)

  local pod_name
  while IFS= read -r pod_name; do
    [ -n "$pod_name" ] || continue
    kube_capture_api \
      "$kube_dir/pod-yaml/$(slugify "$pod_name").yaml" \
      "$kube_dir/pod-yaml/$(slugify "$pod_name").stderr" \
      get pod "$pod_name" -n "$namespace" -o yaml

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
