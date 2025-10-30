#!/bin/bash

## Create values.yaml file
cat <<EOF > values.yaml
$(cat values.template.yaml)
EOF

## setup the helm repo
helm repo add langfuse https://langfuse.github.io/langfuse-k8s  
helm repo update

## check if already installed
helm status ${LANGFUSE_DEPLOYMENT_NAME} -n ${LANGFUSE_K8S_NAMESPACE} > /dev/null 2>&1
if [ $? -ne 0 ]; then
    ## Install if not present
    helm install ${LANGFUSE_DEPLOYMENT_NAME} langfuse/langfuse -n ${LANGFUSE_K8S_NAMESPACE} -f values.yaml
else 
    ## Update if present
    helm upgrade ${LANGFUSE_DEPLOYMENT_NAME} langfuse/langfuse -n ${LANGFUSE_K8S_NAMESPACE} -f values.yaml
fi

