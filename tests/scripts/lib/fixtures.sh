#!/usr/bin/env bash

fixture_dir_for_target() {
  case "$1" in
    network)
      printf '%s\n' "$TESTS_DIR/fixtures/network"
      ;;
    basic)
      printf '%s\n' "$TESTS_DIR/fixtures/cluster-basic"
      ;;
    enhanced)
      printf '%s\n' "$TESTS_DIR/fixtures/cluster-enhanced"
      ;;
    *)
      die "Unknown fixture target: $1"
      ;;
  esac
}

fixture_state_exists() {
  local fixture_dir="$1"
  [ -f "$fixture_dir/terraform.tfstate" ] || [ -d "$fixture_dir/.terraform" ]
}

assert_network_destroy_is_safe() {
  local basic_dir enhanced_dir
  basic_dir="$(fixture_dir_for_target basic)"
  enhanced_dir="$(fixture_dir_for_target enhanced)"
  if fixture_state_exists "$basic_dir" || fixture_state_exists "$enhanced_dir"; then
    die "Cannot destroy or refresh the shared network while cluster fixtures still have state."
  fi
}

assert_fixture_config_exists() {
  local fixture_dir="$1"
  if ! find "$fixture_dir" -maxdepth 1 -type f -name '*.tf' | grep -q .; then
    die "Fixture workspace is scaffolded but has no Terraform files yet: $fixture_dir"
  fi
}

fixture_has_config() {
  local fixture_dir="$1"
  find "$fixture_dir" -maxdepth 1 -type f -name '*.tf' | grep -q .
}

run_fixture_terraform() {
  local fixture_dir="$1"
  local action="$2"
  local artifact_dir="$3"
  shift 3

  require_command terraform
  assert_fixture_config_exists "$fixture_dir"

  local init_args=()
  while IFS= read -r arg; do
    [ -n "$arg" ] && init_args+=("$arg")
  done < <(terraform_init_args)

  terraform -chdir="$fixture_dir" init "${init_args[@]}" >"$artifact_dir/terraform-init.log" 2>&1

  case "$action" in
    status)
      terraform -chdir="$fixture_dir" output -json >"$artifact_dir/outputs.json" 2>&1 || true
      ;;
    up)
      terraform -chdir="$fixture_dir" apply -input=false -auto-approve "$@" >"$artifact_dir/terraform-apply.log" 2>&1
      terraform -chdir="$fixture_dir" output -json >"$artifact_dir/outputs.json"
      ;;
    down)
      terraform -chdir="$fixture_dir" destroy -input=false -auto-approve "$@" >"$artifact_dir/terraform-destroy.log" 2>&1
      ;;
    refresh)
      terraform -chdir="$fixture_dir" destroy -input=false -auto-approve "$@" >"$artifact_dir/terraform-destroy.log" 2>&1
      terraform -chdir="$fixture_dir" apply -input=false -auto-approve "$@" >"$artifact_dir/terraform-apply.log" 2>&1
      terraform -chdir="$fixture_dir" output -json >"$artifact_dir/outputs.json"
      ;;
    *)
      die "Unsupported terraform fixture action: $action"
      ;;
  esac
}

run_fixture_action() {
  local target="$1"
  local action="$2"
  local size="${3:-}"
  require_non_empty "$target" "TARGET is required for fixture command"
  require_non_empty "$action" "ACTION is required for fixture command"

  if [ "$target" = "network" ] && { [ "$action" = "down" ] || [ "$action" = "refresh" ]; }; then
    assert_network_destroy_is_safe
  fi

  local fixture_dir
  fixture_dir="$(fixture_dir_for_target "$target")"
  local artifact_dir
  artifact_dir="$(create_artifact_dir "fixture/$target/$action")"
  log "Running fixture action '$action' for target '$target'"

  if ! fixture_has_config "$fixture_dir"; then
    if [ "$action" = "status" ]; then
      printf '{ "status": "scaffolded", "fixture_dir": "%s" }\n' "$fixture_dir" >"$artifact_dir/status.json"
      log "Fixture workspace is scaffolded but not yet implemented: $fixture_dir"
      return 0
    fi
    die "Fixture workspace is scaffolded but has no Terraform files yet: $fixture_dir"
  fi

  case "$action" in
    status|up|down|refresh)
      run_fixture_terraform "$fixture_dir" "$action" "$artifact_dir"
      ;;
    scale)
      [ "$target" = "enhanced" ] || die "Scale action is only supported for TARGET=enhanced"
      require_non_empty "$size" "SIZE is required for fixture scale action"
      run_fixture_terraform "$fixture_dir" up "$artifact_dir" -var="node_pool_size=$size"
      ;;
    *)
      die "Unknown fixture action: $action"
      ;;
  esac

  log "Fixture action completed. Artifacts: $artifact_dir"
}
