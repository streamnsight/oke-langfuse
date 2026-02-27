#!/bin/bash

# Exit if any of the intermediate steps fail
set -e +x -o pipefail 

# Extract "foo" and "baz" arguments from the input into
# FOO and BAZ shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "OCI_PROFILE=\(.oci_profile) SECRET_STORE_VAULT_ID=\(.secrets_store_vault_id) COMPARTMENT_ID=\(.compartment_id) SECRET_STORE_KEY_ID=\(.secrets_store_key_id) SECRET_NAME=\(.secret_name)"')"

# check if the secret exists; if it does make sure we don't overwrite it
SECRET_OCID=$(oci vault secret list \
  --profile "$OCI_PROFILE" \
  --compartment-id "$COMPARTMENT_ID" \
  --vault-id "$SECRET_STORE_VAULT_ID" \
  --all \
  --query "data[?\"secret-name\"=='${SECRET_NAME}'].id | [0]" \
  --raw-output)

if [ -z "${SECRET_OCID}" ] || [ "$SECRET_OCID" == "" ]; then
    # echo "missing"
    # delete previous key in case they exist
    rm -f ./id_rsa ./id_rsa.pub
    # create the new key
    ssh-keygen -q -t rsa -b 2048 -f ./id_rsa -N "" -C "builder@rms"
    # Placeholder for whatever data-fetching logic your script implements
    SECRET_OCID=$(oci vault secret create-base64 \
        --profile "$OCI_PROFILE" \
        --compartment-id "$COMPARTMENT_ID" \
        --secret-name "${SECRET_NAME}" \
        --secret-content-name "${SECRET_NAME}" \
        --description "builder instance SSH private key" \
        --vault-id "$SECRET_STORE_VAULT_ID" \
        --key-id "$SECRET_STORE_KEY_ID" \
        --secret-content-content "$(base64 -i ./id_rsa)" \
        --secret-content-stage CURRENT \
        | jq -r '.data.id')

    # echo $SECRET_OCID

    rm -f ./id_rsa ./id_rsa.pub

fi

# pull the secret to regen the SSH public key if we don't have the file

SECRET_VALUE=$(oci secrets secret-bundle get \
  --profile "$OCI_PROFILE" \
  --secret-id "$SECRET_OCID" \
  --query 'data."secret-bundle-content".content' \
  --raw-output \
  | base64 --decode)

pub_from_secret() {
  local priv="$1" # private key text

  local fifo
  # key needs to have proper permissions
  umask 077
  fifo=$(mktemp -u)
  mkfifo "$fifo"

  # feed the fifo in the background, then have ssh-keygen read it
  {
    ( printf '%s\n' "$priv" >"$fifo" && sleep 2) &
    ssh-keygen -y -f "$fifo"
  } 
  rm -f "$fifo"
}

# echo $SECRET_VALUE
SSH_PUBLIC_KEY=$(pub_from_secret "$SECRET_VALUE")
# SSH_PUBLIC_KEY=$(ssh-keygen -y -f <(printf '%s\n' "$SECRET_VALUE"))
# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
# , "private_key_secret_ocid":"$secret_ocid"
jq -n --arg SSH_PUBLIC_KEY "$SSH_PUBLIC_KEY" --arg SECRET_OCID "$SECRET_OCID" '{"public_key":$SSH_PUBLIC_KEY, "private_key_secret_ocid":$SECRET_OCID}'