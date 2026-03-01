#!/bin/bash
## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl


# Exit if any of the intermediate steps fail
set -euo pipefail 

# Extract "foo" and "baz" arguments from the input into
# FOO and BAZ shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "DEPLOY_ID=\(.deploy_id) SECRET_STORE_KEY_ID=\(.secrets_store_key_id) SECRET_STORE_VAULT_ID=\(.secrets_store_vault_id) COMPARTMENT_ID=\(.secrets_store_vault_compartment_id) PROFILE=\(.profile)"')"


function get_or_create_secret() {

    local SECRET_NAME="$1"
    local SECRET_VALUE="$2"
    local SECRET_OCID

    SECRET_OCID=$(oci vault secret list \
    --profile ${PROFILE} \
    --compartment-id "$COMPARTMENT_ID" \
    --vault-id "$SECRET_STORE_VAULT_ID" \
    --all \
    --query "data[?\"secret-name\"=='${SECRET_NAME}'].id | [0]" \
    --raw-output)

    if [ -z "${SECRET_OCID}" ] || [ "$SECRET_OCID" == "null" ]|| [ "$SECRET_OCID" == "" ]; then

        echo "creating secret $SECRET_NAME" >&2
        SECRET_OCID=$(oci vault secret create-base64 \
            --profile ${PROFILE} \
            --compartment-id "$COMPARTMENT_ID" \
            --secret-name "${SECRET_NAME}" \
            --secret-content-name "${SECRET_NAME}" \
            --description "${SECRET_NAME}" \
            --vault-id "$SECRET_STORE_VAULT_ID" \
            --key-id "$SECRET_STORE_KEY_ID" \
            --secret-content-content "$(printf '%s' "${SECRET_VALUE}" | base64)" \
            --secret-content-stage CURRENT \
            | jq -r '.data.id')

        echo "created secret $SECRET_NAME" >&2

    fi
    printf '%s' "$SECRET_OCID"
}


OCI_GENAI_GATEWAY_DEFAULT_API_KEY=$(openssl rand -hex 56)
OCI_GENAI_GATEWAY_DEFAULT_API_KEY_SECRET_ID=$(get_or_create_secret "${DEPLOY_ID}_OCI_GENAI_GATEWAY_DEFAULT_API_KEY" "${OCI_GENAI_GATEWAY_DEFAULT_API_KEY}")

# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
# , "private_key_secret_ocid":"$secret_ocid"
jq -n --arg OCI_GENAI_GATEWAY_DEFAULT_API_KEY_SECRET_ID "$OCI_GENAI_GATEWAY_DEFAULT_API_KEY_SECRET_ID" \
'{
"oci_genai_gateway_default_api_key_secret_id":$OCI_GENAI_GATEWAY_DEFAULT_API_KEY_SECRET_ID
}'