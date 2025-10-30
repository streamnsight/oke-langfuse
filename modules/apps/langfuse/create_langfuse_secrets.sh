#!/bin/bash

kubectl create secret generic langfuse-idcs \
    -n ${LANGFUSE_K8S_NAMESPACE} \
    --from-literal="client-id"="${IDCS_CLIENT_ID}" \
    --from-literal="client-secret"="${IDCS_CLIENT_SECRET}" \
    --from-literal="issuer"="${IDCS_HOST}" \
    --from-literal="name"="Oracle IDCS"


kubectl create secret generic langfuse --namespace ${LANGFUSE_K8S_NAMESPACE} \
  --from-literal="encryption-key"="${PASSWORD_ENCRYPTION_KEY}" \
  --from-literal="salt"="${PASSWORD_ENCRYPTION_SALT}" \
  --from-literal="nextauth-secret"="${NEXTAUTH_SECRET}" \
  --from-literal="clickhouse-password"="${CLICKHOUSE_PASSWORD}"

kubectl create secret generic langfuse-s3 --namespace ${LANGFUSE_K8S_NAMESPACE} \
  --from-literal="s3-access-key"="${OBJECTSTORAGE_S3_ACCESS_KEY}" \
  --from-literal="s3-secret-key"="${OBJECTSTORAGE_S3_SECRET_KEY}"

