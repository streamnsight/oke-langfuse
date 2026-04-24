#!/usr/bin/env bash

hcl_quote() {
  local value="${1:-}"
  jq -Rn --arg value "$value" '$value'
}

resolve_oke_worker_image_id() {
  local kubernetes_version="$1"
  local current_image_metadata=""
  if [ -n "${TF_VAR_np1_image_id:-}" ]; then
    require_command oci
    current_image_metadata="$(
      oci $(while IFS= read -r arg; do [ -n "$arg" ] && printf '%q ' "$arg"; done < <(oci_cli_global_args)) \
        compute image get \
        --image-id "${TF_VAR_np1_image_id}" 2>/dev/null || true
    )"
  fi

  local metadata_compartment_id=""
  local metadata_operating_system=""
  local metadata_operating_system_version=""
  if [ -n "$current_image_metadata" ]; then
    metadata_compartment_id="$(printf '%s\n' "$current_image_metadata" | jq -r 'try .data["compartment-id"] // empty')"
    metadata_operating_system="$(printf '%s\n' "$current_image_metadata" | jq -r 'try .data["operating-system"] // empty')"
    metadata_operating_system_version="$(printf '%s\n' "$current_image_metadata" | jq -r 'try .data["operating-system-version"] // empty')"
  fi

  local compartment_id="${2:-${TF_VAR_fixture_image_compartment_id:-${metadata_compartment_id:-${TF_VAR_tenancy_ocid:-}}}}"
  local operating_system="${3:-${TF_VAR_fixture_operating_system:-${metadata_operating_system:-Oracle Linux}}}"
  local operating_system_version="${4:-${TF_VAR_fixture_operating_system_version:-${metadata_operating_system_version:-8}}}"
  local shape="${5:-${TF_VAR_fixture_shape:-${TF_VAR_np1_node_shape:-VM.Standard.E5.Flex}}}"
  local resolver_quiet="${TESTS_IMAGE_RESOLVER_QUIET:-false}"

  require_non_empty "$kubernetes_version" "kubernetes_version is required for OKE worker image resolution."
  require_non_empty "$compartment_id" "compartment_id is required for OKE worker image resolution."
  require_non_empty "$operating_system" "operating_system is required for OKE worker image resolution."
  require_non_empty "$operating_system_version" "operating_system_version is required for OKE worker image resolution."
  require_non_empty "$shape" "shape is required for OKE worker image resolution."
  require_command terraform
  require_command jq

  (
    local scratch_dir=""
    local resolver_artifact_dir=""
    mkdir -p "$ROOT_DIR/.tests-tmp"
    scratch_dir="$(mktemp -d "$ROOT_DIR/.tests-tmp/node-image-selector.XXXXXX")"
    trap 'rm -rf "${scratch_dir:-}"' EXIT

    if [ -n "${TESTS_SCENARIO_ARTIFACT_DIR:-}" ]; then
      resolver_artifact_dir="$TESTS_SCENARIO_ARTIFACT_DIR/resolver/node-image-selector"
      mkdir -p "$resolver_artifact_dir"
    fi

    local init_args=()
    while IFS= read -r arg; do
      [ -n "$arg" ] && init_args+=("$arg")
    done < <(terraform_init_args)

    unset TF_PLUGIN_CACHE_DIR

    {
      printf 'terraform {\n'
      printf '  required_providers {\n'
      printf '    oci = {\n'
      printf '      source = "hashicorp/oci"\n'
      printf '    }\n'
      printf '  }\n'
      printf '}\n\n'
      printf 'provider "oci" {}\n\n'
      printf 'module "node_image_selector" {\n'
      printf '  source = %s\n' "$(hcl_quote "../../modules/oke/node-image-selector")"
      printf '  compartment_id = %s\n' "$(hcl_quote "$compartment_id")"
      printf '  kubernetes_version = %s\n' "$(hcl_quote "$kubernetes_version")"
      printf '  operating_system = %s\n' "$(hcl_quote "$operating_system")"
      printf '  operating_system_version = %s\n' "$(hcl_quote "$operating_system_version")"
      printf '  shape = %s\n' "$(hcl_quote "$shape")"
      printf '}\n\n'
      printf 'output "selected_image_id" {\n'
      printf '  value = module.node_image_selector.selected_image_id\n'
      printf '}\n'
    } >"$scratch_dir/main.tf"

    local init_status=0
    set +e
    terraform -chdir="$scratch_dir" init "${init_args[@]}" >"$scratch_dir/terraform-init.log" 2>&1
    init_status=$?
    set -e
    if [ "$init_status" -ne 0 ]; then
      if [ "$resolver_quiet" = "true" ]; then
        exit 1
      fi
      if [ -n "$resolver_artifact_dir" ]; then
        cp "$scratch_dir/main.tf" "$resolver_artifact_dir/main.tf"
        cp "$scratch_dir/terraform-init.log" "$resolver_artifact_dir/terraform-init.log"
      fi
      printf '[tests] OKE worker image resolver terraform init failed for Kubernetes version %s.\n' "$kubernetes_version" >&2
      if [ -n "$resolver_artifact_dir" ]; then
        printf '[tests] Resolver artifacts: %s\n' "$resolver_artifact_dir" >&2
      fi
      tail -n 40 "$scratch_dir/terraform-init.log" | sed 's/^/[tests]   /' >&2 || true
      die "Failed to initialize the OKE worker image resolver."
    fi

    local apply_status=0
    set +e
    terraform -chdir="$scratch_dir" apply -input=false -auto-approve >"$scratch_dir/terraform-apply.log" 2>&1
    apply_status=$?
    set -e
    if [ "$apply_status" -ne 0 ]; then
      if [ "$resolver_quiet" = "true" ]; then
        exit 1
      fi
      if [ -n "$resolver_artifact_dir" ]; then
        cp "$scratch_dir/main.tf" "$resolver_artifact_dir/main.tf"
        cp "$scratch_dir/terraform-init.log" "$resolver_artifact_dir/terraform-init.log"
        cp "$scratch_dir/terraform-apply.log" "$resolver_artifact_dir/terraform-apply.log"
      fi
      printf '[tests] OKE worker image resolver terraform apply failed for Kubernetes version %s.\n' "$kubernetes_version" >&2
      if [ -n "$resolver_artifact_dir" ]; then
        printf '[tests] Resolver artifacts: %s\n' "$resolver_artifact_dir" >&2
      fi
      tail -n 40 "$scratch_dir/terraform-apply.log" | sed 's/^/[tests]   /' >&2 || true
      die "Failed to apply the OKE worker image resolver."
    fi

    terraform -chdir="$scratch_dir" output -json >"$scratch_dir/terraform-output.json" 2>"$scratch_dir/terraform-output.stderr"

    local resolved_image_id
    resolved_image_id="$(jq -r 'try .selected_image_id.value // empty' "$scratch_dir/terraform-output.json")"
    if [[ ! "$resolved_image_id" =~ ^ocid1\.image\. ]]; then
      if [ "$resolver_quiet" = "true" ]; then
        exit 1
      fi
      if [ -n "$resolver_artifact_dir" ]; then
        cp "$scratch_dir/main.tf" "$resolver_artifact_dir/main.tf"
        cp "$scratch_dir/terraform-init.log" "$resolver_artifact_dir/terraform-init.log"
        cp "$scratch_dir/terraform-apply.log" "$resolver_artifact_dir/terraform-apply.log"
        cp "$scratch_dir/terraform-output.json" "$resolver_artifact_dir/terraform-output.json"
        cp "$scratch_dir/terraform-output.stderr" "$resolver_artifact_dir/terraform-output.stderr"
      fi
      printf '[tests] OKE worker image resolver failed for Kubernetes version %s.\n' "$kubernetes_version" >&2
      if [ -n "$resolver_artifact_dir" ]; then
        printf '[tests] Resolver artifacts: %s\n' "$resolver_artifact_dir" >&2
      fi
      if [ -s "$scratch_dir/terraform-output.stderr" ]; then
        printf '[tests] terraform output stderr:\n' >&2
        sed 's/^/[tests]   /' "$scratch_dir/terraform-output.stderr" >&2
      fi
      if [ -s "$scratch_dir/terraform-apply.log" ]; then
        printf '[tests] terraform apply log (last 40 lines):\n' >&2
        tail -n 40 "$scratch_dir/terraform-apply.log" | sed 's/^/[tests]   /' >&2
      fi
      die "Failed to resolve a valid OKE worker image ID."
    fi

    printf '%s\n' "$resolved_image_id"
  )
}

fixture_outputs_json_for_target() {
  local target="$1"
  local fixture_dir
  fixture_dir="$(fixture_dir_for_target "$target")"
  if [ -f "$fixture_dir/terraform.tfstate" ]; then
    jq -c '.outputs' "$fixture_dir/terraform.tfstate"
  else
    return 1
  fi
}

fixture_output_value() {
  local target="$1"
  local output_name="$2"
  fixture_outputs_json_for_target "$target" | jq -r --arg name "$output_name" '.[$name].value'
}

scenario_require_env_vars() {
  local name
  local missing=()
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then
      missing+=("$name")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    printf '[tests] Missing required environment variables for scenario preparation:\n' >&2
    printf '  - %s\n' "${missing[@]}" >&2
    return 1
  fi
}

write_existing_cluster_tfvars() {
  local outfile="$1"
  local cluster_ocid="$2"
  shift 2
  local include_test_identity_defaults="${STACK_TEST_INCLUDE_IDCS_PLACEHOLDERS:-true}"

  scenario_require_env_vars \
    TF_VAR_region \
    TF_VAR_tenancy_ocid \
    TF_VAR_vcn_compartment_id \
    TF_VAR_cluster_compartment_id \
    TF_VAR_devops_compartment_id \
    TF_VAR_secrets_store_vault_compartment_id \
    TF_VAR_secrets_store_vault_id \
    TF_VAR_secrets_store_key_id \
    TF_VAR_langfuse_s3_access_key \
    TF_VAR_langfuse_s3_secret_key \
    TF_VAR_ssh_public_key \
    TF_VAR_np1_image_id

  {
    printf 'region = %s\n' "$(hcl_quote "$TF_VAR_region")"
    printf 'tenancy_ocid = %s\n' "$(hcl_quote "$TF_VAR_tenancy_ocid")"
    printf 'oci_profile = %s\n' "$(hcl_quote "${TF_VAR_oci_profile:-${OCI_PROFILE:-DEFAULT}}")"
    printf 'vcn_compartment_id = %s\n' "$(hcl_quote "$TF_VAR_vcn_compartment_id")"
    printf 'cluster_compartment_id = %s\n' "$(hcl_quote "$TF_VAR_cluster_compartment_id")"
    printf 'devops_compartment_id = %s\n' "$(hcl_quote "$TF_VAR_devops_compartment_id")"
    printf 'secrets_store_vault_compartment_id = %s\n' "$(hcl_quote "$TF_VAR_secrets_store_vault_compartment_id")"
    printf 'secrets_store_vault_id = %s\n' "$(hcl_quote "$TF_VAR_secrets_store_vault_id")"
    printf 'secrets_store_key_id = %s\n' "$(hcl_quote "$TF_VAR_secrets_store_key_id")"
    printf 'langfuse_s3_access_key = %s\n' "$(hcl_quote "$TF_VAR_langfuse_s3_access_key")"
    printf 'langfuse_s3_secret_key = %s\n' "$(hcl_quote "$TF_VAR_langfuse_s3_secret_key")"
    printf 'ssh_public_key = %s\n' "$(hcl_quote "$TF_VAR_ssh_public_key")"
    printf 'use_existing_cluster = true\n'
    printf 'cluster_ocid = %s\n' "$(hcl_quote "$cluster_ocid")"
    printf 'create_bastion = false\n'
    printf 'enable_oci_genai_gateway = false\n'
    printf 'test_mode = true\n'

    if [ "$include_test_identity_defaults" = "true" ]; then
      printf 'create_idcs_app = false\n'
      printf 'idcs_app_id = %s\n' "$(hcl_quote "${TF_VAR_idcs_app_id:-test-idcs-app}")"
      printf 'idcs_client_id = %s\n' "$(hcl_quote "${TF_VAR_idcs_client_id:-test-idcs-client}")"
      printf 'idcs_client_secret = %s\n' "$(hcl_quote "${TF_VAR_idcs_client_secret:-test-idcs-secret}")"
      printf 'idcs_domain_url = %s\n' "$(hcl_quote "${TF_VAR_idcs_domain_url:-https://example.invalid}")"
    fi

    if [ -n "${TF_VAR_kubernetes_version:-}" ]; then
      printf 'kubernetes_version = %s\n' "$(hcl_quote "$TF_VAR_kubernetes_version")"
    fi

    for line in "$@"; do
      printf '%s\n' "$line"
    done
  } >"$outfile"
}

write_existing_cluster_with_network_tfvars() {
  local outfile="$1"
  local cluster_ocid="$2"
  shift 2

  local vcn_id
  local kubernetes_endpoint_subnet
  local public_lb_subnet
  local np1_subnet

  vcn_id="$(fixture_output_value network vcn_id)"
  kubernetes_endpoint_subnet="$(fixture_output_value network kubernetes_endpoint_subnet_id)"
  public_lb_subnet="$(fixture_output_value network public_lb_subnet_id)"
  np1_subnet="$(fixture_output_value network node_pool_subnet_ids_by_name | jq -r '.np1')"

  write_existing_cluster_tfvars \
    "$outfile" \
    "$cluster_ocid" \
    "use_existing_vcn = true" \
    "vcn_id = $(hcl_quote "$vcn_id")" \
    "kubernetes_endpoint_subnet = $(hcl_quote "$kubernetes_endpoint_subnet")" \
    "public_lb_subnet = $(hcl_quote "$public_lb_subnet")" \
    "np1_subnet = $(hcl_quote "$np1_subnet")" \
    "$@"
}

write_managed_cluster_with_network_tfvars() {
  local outfile="$1"
  shift
  local include_test_identity_defaults="${STACK_TEST_INCLUDE_IDCS_PLACEHOLDERS:-true}"

  local vcn_id
  local kubernetes_endpoint_subnet
  local public_lb_subnet
  local np1_subnet

  vcn_id="$(fixture_output_value network vcn_id)"
  kubernetes_endpoint_subnet="$(fixture_output_value network kubernetes_endpoint_subnet_id)"
  public_lb_subnet="$(fixture_output_value network public_lb_subnet_id)"
  np1_subnet="$(fixture_output_value network node_pool_subnet_ids_by_name | jq -r '.np1')"

  scenario_require_env_vars \
    TF_VAR_region \
    TF_VAR_tenancy_ocid \
    TF_VAR_vcn_compartment_id \
    TF_VAR_cluster_compartment_id \
    TF_VAR_devops_compartment_id \
    TF_VAR_secrets_store_vault_compartment_id \
    TF_VAR_secrets_store_vault_id \
    TF_VAR_secrets_store_key_id \
    TF_VAR_langfuse_s3_access_key \
    TF_VAR_langfuse_s3_secret_key \
    TF_VAR_ssh_public_key

  {
    printf 'region = %s\n' "$(hcl_quote "$TF_VAR_region")"
    printf 'tenancy_ocid = %s\n' "$(hcl_quote "$TF_VAR_tenancy_ocid")"
    printf 'oci_profile = %s\n' "$(hcl_quote "${TF_VAR_oci_profile:-${OCI_PROFILE:-DEFAULT}}")"
    printf 'vcn_compartment_id = %s\n' "$(hcl_quote "$TF_VAR_vcn_compartment_id")"
    printf 'cluster_compartment_id = %s\n' "$(hcl_quote "$TF_VAR_cluster_compartment_id")"
    printf 'devops_compartment_id = %s\n' "$(hcl_quote "$TF_VAR_devops_compartment_id")"
    printf 'secrets_store_vault_compartment_id = %s\n' "$(hcl_quote "$TF_VAR_secrets_store_vault_compartment_id")"
    printf 'secrets_store_vault_id = %s\n' "$(hcl_quote "$TF_VAR_secrets_store_vault_id")"
    printf 'secrets_store_key_id = %s\n' "$(hcl_quote "$TF_VAR_secrets_store_key_id")"
    printf 'langfuse_s3_access_key = %s\n' "$(hcl_quote "$TF_VAR_langfuse_s3_access_key")"
    printf 'langfuse_s3_secret_key = %s\n' "$(hcl_quote "$TF_VAR_langfuse_s3_secret_key")"
    printf 'ssh_public_key = %s\n' "$(hcl_quote "$TF_VAR_ssh_public_key")"
    printf 'use_existing_vcn = true\n'
    printf 'vcn_id = %s\n' "$(hcl_quote "$vcn_id")"
    printf 'kubernetes_endpoint_subnet = %s\n' "$(hcl_quote "$kubernetes_endpoint_subnet")"
    printf 'public_lb_subnet = %s\n' "$(hcl_quote "$public_lb_subnet")"
    printf 'np1_subnet = %s\n' "$(hcl_quote "$np1_subnet")"
    printf 'create_bastion = false\n'
    printf 'enable_oci_genai_gateway = false\n'
    printf 'test_mode = true\n'

    if [ "$include_test_identity_defaults" = "true" ]; then
      printf 'create_idcs_app = false\n'
      printf 'idcs_app_id = %s\n' "$(hcl_quote "${TF_VAR_idcs_app_id:-test-idcs-app}")"
      printf 'idcs_client_id = %s\n' "$(hcl_quote "${TF_VAR_idcs_client_id:-test-idcs-client}")"
      printf 'idcs_client_secret = %s\n' "$(hcl_quote "${TF_VAR_idcs_client_secret:-test-idcs-secret}")"
      printf 'idcs_domain_url = %s\n' "$(hcl_quote "${TF_VAR_idcs_domain_url:-https://example.invalid}")"
    fi

    for line in "$@"; do
      printf '%s\n' "$line"
    done
  } >"$outfile"
}

append_live_identity_tfvars() {
  local outfile="$1"

  if [ -n "${TF_VAR_identity_domain_id:-}" ]; then
    {
      printf 'create_idcs_app = true\n'
      printf 'identity_domain_id = %s\n' "$(hcl_quote "$TF_VAR_identity_domain_id")"
    } >>"$outfile"
    return 0
  fi

  scenario_require_env_vars \
    TF_VAR_idcs_app_id \
    TF_VAR_idcs_client_id \
    TF_VAR_idcs_client_secret \
    TF_VAR_idcs_domain_url || die "Full live deployment requires TF_VAR_identity_domain_id or the full TF_VAR_idcs_* set."

  {
    printf 'create_idcs_app = false\n'
    printf 'idcs_app_id = %s\n' "$(hcl_quote "$TF_VAR_idcs_app_id")"
    printf 'idcs_client_id = %s\n' "$(hcl_quote "$TF_VAR_idcs_client_id")"
    printf 'idcs_client_secret = %s\n' "$(hcl_quote "$TF_VAR_idcs_client_secret")"
    printf 'idcs_domain_url = %s\n' "$(hcl_quote "$TF_VAR_idcs_domain_url")"
  } >>"$outfile"
}
