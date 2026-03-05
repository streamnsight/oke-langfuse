#!/bin/bash
## Copyright © 2022-2026, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

set -e -x 

echo "Getting KubeConfig"

rm -f ~/.kube/config
oci --auth resource_principal ce cluster create-kubeconfig --cluster-id ${CLUSTER_ID} --file ~/.kube/config --region ${REGION} --token-version 2.0.0  --kube-endpoint PRIVATE_ENDPOINT
# edit the kubeconfig to use instance principal auth
sed -i '23i\      - --auth' ~/.kube/config
sed -i '24i\      - resource_principal' ~/.kube/config


function get_secret() {
    # pull the secret value

    SECRET_OCID=$(oci vault secret list \
    --auth resource_principal \
    --compartment-id "$SECRETS_STORE_VAULT_COMPARTMENT_ID" \
    --vault-id "$SECRETS_STORE_VAULT_ID" \
    --all \
    --query "data[?\"secret-name\"=='${1}'].id | [0]" \
    --raw-output)

    SECRET_VALUE=$(oci secrets secret-bundle get \
    --auth resource_principal \
    --secret-id "$SECRET_OCID" \
    --query 'data."secret-bundle-content".content' \
    --raw-output \
    | base64 --decode)

    printf '%s' "$SECRET_VALUE"
}

kubectl get namespace langfuse || kubectl create namespace langfuse

# oci-genai-gateway default API key value
kubectl get secret oci-genai-gateway -n langfuse \
&& kubectl delete secret oci-genai-gateway -n langfuse

kubectl create secret generic oci-genai-gateway \
    --namespace langfuse \
    --from-literal="DEFAULT_API_KEYS"="$(get_secret ${DEPLOY_ID}_OCI_GENAI_GATEWAY_DEFAULT_API_KEY)"
