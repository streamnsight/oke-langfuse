# #!/bin/bash

# set -x 

# cd ${MODULE_PATH}
# ls -lah

# ## Get cluster kubeconfig
# # mkdir -k ~/.kube
# # oci ce cluster create-kubeconfig --cluster-id ${CLUSTER_ID} --file $HOME/.kube/config --region ${REGION} --token-version 2.0.0  --kube-endpoint PRIVATE_ENDPOINT --auth instance_principal

# cat ../../../kubeconfig
# export KUBECONFIG=../../../kubeconfig

# ## Setup proxy connection
# ssh -o StrictHostKeyChecking=accept-new -i bastionKey.pem -N -D 127.0.0.1:1088 -p 22 ${BASTION_SESSION_ID}@host.bastion.${REGION}.oci.oraclecloud.com &
# PROXY_PID=$!

# export HTTP_PROXY="socks5://127.0.0.1:1088"
# export HTTPS_PROXY="socks5://127.0.0.1:1088"

# kubectl get pods -A

# ## IDCS Secrets
# kubectl create secret generic langfuse-idcs \
#     -n ${LANGFUSE_K8S_NAMESPACE} \
#     --from-literal="client-id"="${IDCS_CLIENT_ID}" \
#     --from-literal="client-secret"="${IDCS_CLIENT_SECRET}" \
#     --from-literal="issuer"="httpshttps://idcs-${IDCS_APP_ID}.identity.oraclecloud.com" \
#     --from-literal="name"="Oracle IDCS"

# ## Langfuse auth
# kubectl create secret generic langfuse --namespace ${LANGFUSE_K8S_NAMESPACE} \
#   --from-literal="encryption-key"="${PASSWORD_ENCRYPTION_KEY}" \
#   --from-literal="salt"="${PASSWORD_ENCRYPTION_SALT}" \
#   --from-literal="nextauth-secret"="${NEXTAUTH_SECRET}" \
#   --from-literal="clickhouse-password"="${CLICKHOUSE_PASSWORD}"

# ## Object Storage access
# kubectl create secret generic langfuse-s3 --namespace ${LANGFUSE_K8S_NAMESPACE} \
#   --from-literal="s3-access-key"="${OBJECTSTORAGE_S3_ACCESS_KEY}" \
#   --from-literal="s3-secret-key"="${OBJECTSTORAGE_S3_SECRET_KEY}"

# ## Postgres DB TLS Cert
# echo ${PSQL_CERTIFICATE} > CaCertificate-langfuse.pub

# kubectl create secret generic langfuse-postgres-cert \
#     -n ${LANGFUSE_K8S_NAMESPACE} --from-file=CaCertificate-langfuse.pub

# rm -f CaCertificate-langfuse.pub

# ## Postgres DB Connection
# kubectl create secret generic langfuse-postgres \
#     -n ${LANGFUSE_K8S_NAMESPACE} \
#     --from-literal="postgres-password"="${PSQL_PASSWORD}" \
#     --from-literal="database-url"="postgresql://langfuse:${PSQL_PASSWORD}@${PSQL_HOST}:5432/postgres?sslmode=verify-full&sslrootcert=/secrets/db-keystore/CaCertificate-langfuse.pub"
    
# kill $PROXY_PID