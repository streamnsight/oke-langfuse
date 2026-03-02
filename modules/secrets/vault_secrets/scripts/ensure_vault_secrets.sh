#!/bin/bash
## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# Exit if any of the intermediate steps fail
set -euo pipefail

# Extract arguments from the input into shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "PROFILE=\(.profile) COMPARTMENT_ID=\(.compartment_id) VAULT_ID=\(.vault_id) KEY_ID=\(.key_id) SECRETS_JSON=\(.secrets_json)"')"

require_non_empty() {
    local VALUE_NAME="$1"
    local VALUE="$2"

    if [ -z "${VALUE}" ] || [ "${VALUE}" = "null" ]; then
        echo "Required value '${VALUE_NAME}' is empty." >&2
        exit 1
    fi
}

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
        --vault-id "$VAULT_ID" \
        --all \
        --query "data[?\"secret-name\"=='${SECRET_NAME}' && \"lifecycle-state\"=='ACTIVE'].id | [0]" \
        --raw-output)

    if [ -z "${SECRET_OCID}" ] || [ "${SECRET_OCID}" = "null" ]; then
        SECRET_OCID=$(oci vault secret list \
            --profile ${PROFILE} \
            --compartment-id "$COMPARTMENT_ID" \
            --vault-id "$VAULT_ID" \
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
            --vault-id "$VAULT_ID" \
            --key-id "$KEY_ID" \
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

generate_secret_value() {
    local GENERATOR_TYPE="$1"
    local GENERATOR_BYTES="$2"

    case "${GENERATOR_TYPE}" in
        openssl_hex)
            if [ -z "${GENERATOR_BYTES}" ] || [ "${GENERATOR_BYTES}" = "null" ]; then
                echo "Generator bytes are required for openssl_hex." >&2
                exit 1
            fi
            openssl rand -hex "${GENERATOR_BYTES}"
            ;;
        *)
            echo "Unsupported generator type: ${GENERATOR_TYPE}" >&2
            exit 1
            ;;
    esac
}

require_non_empty "SECRETS_JSON" "${SECRETS_JSON}"

SECRET_OCIDS_JSON='{}'

while IFS= read -r SECRET_ITEM; do
    SECRET_NAME=$(jq -r '.name' <<< "${SECRET_ITEM}")
    VALUE_PRESENT=$(jq -r 'has("value")' <<< "${SECRET_ITEM}")
    SECRET_VALUE=$(jq -r '.value // empty' <<< "${SECRET_ITEM}")
    REQUIRED=$(jq -r '.required // true' <<< "${SECRET_ITEM}")
    GENERATOR_TYPE=$(jq -r '.generator.type // empty' <<< "${SECRET_ITEM}")
    GENERATOR_BYTES=$(jq -r '.generator.bytes // empty' <<< "${SECRET_ITEM}")

    require_non_empty "secret.name" "${SECRET_NAME}"

    if [ -n "${GENERATOR_TYPE}" ] && [ "${VALUE_PRESENT}" = "true" ]; then
        echo "Secret ${SECRET_NAME} cannot specify both 'value' and 'generator'." >&2
        exit 1
    fi

    if [ -z "${GENERATOR_TYPE}" ] && [ "${VALUE_PRESENT}" = "false" ]; then
        echo "Secret ${SECRET_NAME} must specify either 'value' or 'generator'." >&2
        exit 1
    fi

    if [ -n "${GENERATOR_TYPE}" ]; then
        SECRET_VALUE=$(generate_secret_value "${GENERATOR_TYPE}" "${GENERATOR_BYTES}")
    else
        if [ "${REQUIRED}" = "true" ]; then
            require_non_empty "secret.value (${SECRET_NAME})" "${SECRET_VALUE}"
        elif [ -z "${SECRET_VALUE}" ] || [ "${SECRET_VALUE}" = "null" ]; then
            echo "Skipping optional secret ${SECRET_NAME} with empty value." >&2
            continue
        fi
    fi

    SECRET_OCID=$(get_or_create_secret "${SECRET_NAME}" "${SECRET_VALUE}")
    SECRET_OCIDS_JSON=$(jq -c --arg name "${SECRET_NAME}" --arg value "${SECRET_OCID}" '. + {($name): $value}' <<< "${SECRET_OCIDS_JSON}")

done < <(echo "${SECRETS_JSON}" | jq -c '.[]')

jq -n --arg secret_ocids_json "${SECRET_OCIDS_JSON}" '{secret_ocids_json: $secret_ocids_json}'
