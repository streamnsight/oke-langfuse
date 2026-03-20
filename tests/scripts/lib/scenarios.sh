#!/usr/bin/env bash

hcl_quote() {
  local value="${1:-}"
  jq -Rn --arg value "$value" '$value'
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
    printf 'use_existing_cluster = true\n'
    printf 'cluster_ocid = %s\n' "$(hcl_quote "$cluster_ocid")"
    printf 'create_bastion = false\n'
    printf 'create_idcs_app = false\n'
    printf 'idcs_app_id = %s\n' "$(hcl_quote "${TF_VAR_idcs_app_id:-test-idcs-app}")"
    printf 'idcs_client_id = %s\n' "$(hcl_quote "${TF_VAR_idcs_client_id:-test-idcs-client}")"
    printf 'idcs_client_secret = %s\n' "$(hcl_quote "${TF_VAR_idcs_client_secret:-test-idcs-secret}")"
    printf 'idcs_domain_url = %s\n' "$(hcl_quote "${TF_VAR_idcs_domain_url:-https://example.invalid}")"
    printf 'enable_oci_genai_gateway = false\n'
    printf 'test_mode = true\n'

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
