#!/bin/bash
## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl


# Exit if any of the intermediate steps fail
set -euo pipefail 

# Extract "foo" and "baz" arguments from the input into
# FOO and BAZ shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "DEPLOY_ID=\(.deploy_id) SECRETS_STORE_KEY_ID=\(.secrets_store_key_id) SECRETS_STORE_VAULT_ID=\(.secrets_store_vault_id) COMPARTMENT_ID=\(.secrets_store_vault_compartment_id) PROFILE=\(.profile) IDCS_CLIENT_ID=\(.idcs_client_id) IDCS_CLIENT_SECRET=\(.idcs_client_secret) IDCS_ISSUER=\(.idcs_issuer) S3_ACCESS_KEY=\(.s3_access_key) S3_SECRET_KEY=\(.s3_secret_key) PSQL_PASSWORD=\(.psql_password) PSQL_URL=\(.psql_url)"')"

require_non_empty() {
    local VALUE_NAME="$1"
    local VALUE="$2"

    if [ -z "${VALUE}" ] || [ "${VALUE}" = "null" ]; then
        echo "Required value '${VALUE_NAME}' is empty." >&2
        exit 1
    fi
}

require_non_empty "IDCS_CLIENT_ID" "${IDCS_CLIENT_ID}"
require_non_empty "IDCS_CLIENT_SECRET" "${IDCS_CLIENT_SECRET}"
require_non_empty "IDCS_ISSUER" "${IDCS_ISSUER}"
require_non_empty "S3_ACCESS_KEY" "${S3_ACCESS_KEY}"
require_non_empty "S3_SECRET_KEY" "${S3_SECRET_KEY}"
require_non_empty "PSQL_PASSWORD" "${PSQL_PASSWORD}"
require_non_empty "PSQL_URL" "${PSQL_URL}"

wait_for_secret_active() {
    local SECRET_ID="$1"
    local MAX_ATTEMPTS="${2:-30}"
    local SLEEP_SECONDS="${3:-10}"
    local ATTEMPT=1
    local STATE

    while true; do
        STATE=$(oci vault secret get \
            --profile ${PROFILE} \
            --secret-id "${SECRET_ID}" \
            --query 'data."lifecycle-state"' \
            --raw-output 2>/dev/null || true)

        if [ "${STATE}" = "ACTIVE" ]; then
            return 0
        fi

        if [ "${STATE}" = "DELETED" ] || [ "${STATE}" = "DELETING" ] || [ "${STATE}" = "FAILED" ] || [ "${STATE}" = "PENDING_DELETION" ]; then
            echo "Secret ${SECRET_ID} is in bad state: ${STATE}." >&2
            return 1
        fi

        if [ "${ATTEMPT}" -ge "${MAX_ATTEMPTS}" ]; then
            echo "Timed out waiting for secret ${SECRET_ID} to become ACTIVE." >&2
            return 1
        fi

        ATTEMPT=$((ATTEMPT + 1))
        sleep "${SLEEP_SECONDS}"
    done
}

get_or_create_secret() {
    local SECRET_NAME="$1"
    local SECRET_VALUE="$2"
    local SECRET_OCID

    SECRET_OCID=$(oci vault secret list \
        --profile ${PROFILE} \
        --compartment-id "$COMPARTMENT_ID" \
        --vault-id "$SECRETS_STORE_VAULT_ID" \
        --all \
        --query "data[?\"secret-name\"=='${SECRET_NAME}' && \"lifecycle-state\"=='ACTIVE'].id | [0]" \
        --raw-output)

    if [ -z "${SECRET_OCID}" ] || [ "${SECRET_OCID}" = "null" ]; then
        SECRET_OCID=$(oci vault secret list \
            --profile ${PROFILE} \
            --compartment-id "$COMPARTMENT_ID" \
            --vault-id "$SECRETS_STORE_VAULT_ID" \
            --all \
            --query "data[?\"secret-name\"=='${SECRET_NAME}'].id | [0]" \
            --raw-output)
    fi

    if [ -z "${SECRET_OCID}" ] || [ "${SECRET_OCID}" = "null" ]; then
        echo "creating secret ${SECRET_NAME}" >&2
        SECRET_OCID=$(oci vault secret create-base64 \
            --profile ${PROFILE} \
            --compartment-id "$COMPARTMENT_ID" \
            --secret-name "${SECRET_NAME}" \
            --secret-content-name "${SECRET_NAME}" \
            --description "${SECRET_NAME}" \
            --vault-id "$SECRETS_STORE_VAULT_ID" \
            --key-id "$SECRETS_STORE_KEY_ID" \
            --secret-content-content "$(printf '%s' "${SECRET_VALUE}" | base64)" \
            --secret-content-stage CURRENT \
            | jq -r '.data.id')
        echo "created secret ${SECRET_NAME}" >&2
    fi

    if [ -z "${SECRET_OCID}" ] || [ "${SECRET_OCID}" = "null" ]; then
        echo "Failed to resolve secret OCID for ${SECRET_NAME}." >&2
        exit 1
    fi

    wait_for_secret_active "${SECRET_OCID}"
    printf '%s' "${SECRET_OCID}"
}


ENCRYPTION_KEY=$(openssl rand -hex 32)
ENCRYPTION_KEY_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_ENCRYPTION_KEY" "${ENCRYPTION_KEY}")

SALT=$(openssl rand -hex 24)
SALT_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_PASSWORD_ENCRYPTION_SALT" "${SALT}")

NEXTAUTH_SECRET=$(openssl rand -hex 48)
NEXTAUTH_SECRET_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_NEXTAUTH_SECRET" "${NEXTAUTH_SECRET}")

CLICKHOUSE_PASSWORD=$(openssl rand -hex 24)
CLICKHOUSE_PASSWORD_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_CLICKHOUSE_PASSWORD" "${CLICKHOUSE_PASSWORD}")

REDIS_PASSWORD=$(openssl rand -hex 24)
REDIS_PASSWORD_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_REDIS_PASSWORD" "${REDIS_PASSWORD}")

IDCS_CLIENT_ID_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_IDCS_CLIENT_ID" "${IDCS_CLIENT_ID}")
IDCS_CLIENT_SECRET_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_IDCS_CLIENT_SECRET" "${IDCS_CLIENT_SECRET}")
IDCS_ISSUER_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_IDCS_ISSUER" "${IDCS_ISSUER}")
S3_ACCESS_KEY_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_S3_ACCESS_KEY" "${S3_ACCESS_KEY}")
S3_SECRET_KEY_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_S3_SECRET_KEY" "${S3_SECRET_KEY}")
PSQL_PASSWORD_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_PSQL_PASSWORD" "${PSQL_PASSWORD}")
PSQL_URL_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_LANGFUSE_PSQL_URL" "${PSQL_URL}")


# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
# , "private_key_secret_ocid":"$secret_ocid"
jq -n --arg ENCRYPTION_KEY_SECRET_ID "$ENCRYPTION_KEY_SECRET_ID" \
    --arg SALT_SECRET_ID "$SALT_SECRET_ID" \
    --arg NEXTAUTH_SECRET_SECRET_ID "$NEXTAUTH_SECRET_SECRET_ID" \
    --arg CLICKHOUSE_PASSWORD_SECRET_ID "$CLICKHOUSE_PASSWORD_SECRET_ID" \
    --arg REDIS_PASSWORD_SECRET_ID "$REDIS_PASSWORD_SECRET_ID" \
    --arg IDCS_CLIENT_ID_SECRET_ID "$IDCS_CLIENT_ID_SECRET_ID" \
    --arg IDCS_CLIENT_SECRET_SECRET_ID "$IDCS_CLIENT_SECRET_SECRET_ID" \
    --arg IDCS_ISSUER_SECRET_ID "$IDCS_ISSUER_SECRET_ID" \
    --arg S3_ACCESS_KEY_SECRET_ID "$S3_ACCESS_KEY_SECRET_ID" \
    --arg S3_SECRET_KEY_SECRET_ID "$S3_SECRET_KEY_SECRET_ID" \
    --arg PSQL_PASSWORD_SECRET_ID "$PSQL_PASSWORD_SECRET_ID" \
    --arg PSQL_URL_SECRET_ID "$PSQL_URL_SECRET_ID" \
'{
"encryption_key_secret_id":$ENCRYPTION_KEY_SECRET_ID,
"salt_secret_id":$SALT_SECRET_ID,
"nextauth_secret_secret_id":$NEXTAUTH_SECRET_SECRET_ID,
"clickhouse_password_secret_id":$CLICKHOUSE_PASSWORD_SECRET_ID,
"redis_password_secret_id":$REDIS_PASSWORD_SECRET_ID,
"idcs_client_id_secret_id":$IDCS_CLIENT_ID_SECRET_ID,
"idcs_client_secret_secret_id":$IDCS_CLIENT_SECRET_SECRET_ID,
"idcs_issuer_secret_id":$IDCS_ISSUER_SECRET_ID,
"s3_access_key_secret_id":$S3_ACCESS_KEY_SECRET_ID,
"s3_secret_key_secret_id":$S3_SECRET_KEY_SECRET_ID,
"psql_password_secret_id":$PSQL_PASSWORD_SECRET_ID,
"psql_url_secret_id":$PSQL_URL_SECRET_ID
}'
