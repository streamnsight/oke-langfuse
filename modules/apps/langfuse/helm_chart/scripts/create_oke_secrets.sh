#!/bin/bash
## Copyright © 2022-2026, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

set -e 

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
    --compartment-id "$COMPARTMENT_ID" \
    --vault-id "$SECRET_STORE_VAULT_ID" \
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

# langfuse password hashing
kubectl get secret langfuse -n langfuse \
&& kubectl delete secret langfuse -n langfuse

kubectl create secret generic langfuse \
    --namespace langfuse \
    --from-literal="encryption-key"="$(get_secret ${DEPLOY_ID}_LANGFUSE_ENCRYPTION_KEY)" \
    --from-literal="salt"="$(get_secret ${DEPLOY_ID}_LANGFUSE_PASSWORD_ENCRYPTION_SALT)" \
    --from-literal="nextauth-secret"="$(get_secret ${DEPLOY_ID}_LANGFUSE_NEXTAUTH_SECRET)" \
    --from-literal="clickhouse-password"="$(get_secret ${DEPLOY_ID}_LANGFUSE_CLICKHOUSE_PASSWORD)" \
    --from-literal="redis-password"="$(get_secret ${DEPLOY_ID}_LANGFUSE_REDIS_PASSWORD)"

# langfuse IDCS secrets
kubectl get secret langfuse-idcs -n langfuse \
&& kubectl delete secret langfuse-idcs -n langfuse

kubectl create secret generic langfuse-idcs \
    --namespace langfuse \
    --from-literal="client-id"="$(get_secret ${DEPLOY_ID}_LANGFUSE_IDCS_CLIENT_ID)" \
    --from-literal="client-secret"="$(get_secret ${DEPLOY_ID}_LANGFUSE_IDCS_ISSUER)" \
    --from-literal="issuer"="$(get_secret ${DEPLOY_ID}_LANGFUSE_IDCS_ISSUER)" \
    --from-literal="name"="Oracle IDCS"

# Langfuse Object Storage access keys
kubectl get secret langfuse-s3 -n langfuse \
&& kubectl delete secret langfuse-s3 -n langfuse

kubectl create secret generic langfuse-s3 \
    --namespace langfuse \
    --from-literal="s3-access-key"="$(get_secret ${DEPLOY_ID}_LANGFUSE_S3_ACCESS_KEY)" \
    --from-literal="s3-secret-key"="$(get_secret ${DEPLOY_ID}_LANGFUSE_S3_SECRET_KEY)"

# langfuse Postgres cert
kubectl get secret langfuse-postgres-cert -n langfuse \
&& kubectl delete secret langfuse-postgres-cert -n langfuse

oci psql db-system get \
  --auth resource_principal \
  --db-system-id "${PSQL_OCID}" \
  --query 'data."ssl-ca-certificate"' \
  --raw-output > CaCertificate-langfuse.pub

kubectl create secret generic langfuse-postgres-cert \
    --namespace langfuse \
    --from-file=CaCertificate-langfuse.pub

rm -f CaCertificate-langfuse.pub

# langfuse postgres password and connection string
kubectl get secret langfuse-postgres -n langfuse \
&& kubectl delete secret langfuse-postgres -n langfuse

kubectl create secret generic langfuse-postgres \
    --namespace langfuse \
    --from-literal="postgres-password"="$(get_secret ${DEPLOY_ID}_LANGFUSE_PSQL_PASSWORD)" \
    --from-literal="database-url"="$(get_secret ${DEPLOY_ID}_LANGFUSE_PSQL_URL)"
