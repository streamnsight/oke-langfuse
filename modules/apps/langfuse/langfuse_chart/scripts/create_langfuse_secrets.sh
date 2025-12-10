#!/bin/bash
set -e -o pipefail

# langfuse password hashing
kubectl get secret langfuse -n langfuse \
&& kubectl delete secret langfuse -n langfuse

kubectl create secret generic langfuse \
    --namespace langfuse \
    --from-literal="encryption-key"="${encryption_key}" \
    --from-literal="salt"="${salt}" \
    --from-literal="nextauth-secret"="${nextauth_secret}" \
    --from-literal="clickhouse-password"="${clickhouse_password}" \
    --from-literal="redis-password"="${redis_password}"

# langfuse IDCS secrets
kubectl get secret langfuse-idcs -n langfuse \
&& kubectl delete secret langfuse-idcs -n langfuse

kubectl create secret generic langfuse-idcs \
    --namespace langfuse \
    --from-literal="client-id"="${client_id}" \
    --from-literal="client-secret"="${client_secret}" \
    --from-literal="issuer"="${issuer}" \
    --from-literal="name"="Oracle IDCS"

# Langfuse Object Storage access keys
kubectl get secret langfuse-s3 -n langfuse \
&& kubectl delete secret langfuse-s3 -n langfuse

kubectl create secret generic langfuse-s3 \
    --namespace langfuse \
    --from-literal="s3-access-key"="${s3_access_key}" \
    --from-literal="s3-secret-key"="${s3_secret_key}"

# langfuse Postgres cert
kubectl get secret langfuse-postgres-cert -n langfuse \
&& kubectl delete secret langfuse-postgres-cert -n langfuse

kubectl create secret generic langfuse-postgres-cert \
    --namespace langfuse \
    --from-file=CaCertificate-langfuse.pub

rm -f CaCertificate-langfuse.pub

# langfuse postgres password and connection string
kubectl get secret langfuse-postgres -n langfuse \
&& kubectl delete secret langfuse-postgres -n langfuse

kubectl create secret generic langfuse-postgres \
    --namespace langfuse \
    --from-literal="postgres-password"="${postgres_password}" \
    --from-literal="database-url"="${database_url}"
