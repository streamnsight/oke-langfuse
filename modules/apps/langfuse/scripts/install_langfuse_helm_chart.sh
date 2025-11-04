#!/bin/bash

set -x

## Start Proxy
cd ${MODULE_PATH}

## Get cluster kubeconfig
# mkdir -k ~/.kube
# oci ce cluster create-kubeconfig --cluster-id ${CLUSTER_ID} --file $HOME/.kube/config --region ${REGION} --token-version 2.0.0  --kube-endpoint PRIVATE_ENDPOINT --auth resource_principal

cat ../../../kubeconfig
export KUBECONFIG=../../../kubeconfig

ssh -o StrictHostKeyChecking=accept-new -i bastionKey.pem -N -D 127.0.0.1:1088 -p 22 ${BASTION_SESSION_ID}@host.bastion.${REGION}.oci.oraclecloud.com &
PROXY_PID=$!

export HTTP_PROXY="socks5://127.0.0.1:1088"
export HTTPS_PROXY="socks5://127.0.0.1:1088"

export LANGFUSE_IMAGE_VERSION=$(cat langfuse.version)

kubectl get pods -A

## Deploy Load Balancer
kubectl apply -f ./manifests/langfuse.Service.yaml --wait

## check until it's ready

# get the LB IP -> LANGFUSE_HOSTNAME
export LANGFUSE_HOSTNAME=$(kubectl get svc langfuse-web-lb -n ${LANGFUSE_K8S_NAMESPACE} | awk '{print $4}' | grep -v EXTERNAL-IP)

## Create values.yaml file
eval "echo \"$(cat ./scripts/values.template.yaml)\"" > values.yaml

cat values.yaml

## setup the helm repo
helm repo add langfuse https://langfuse.github.io/langfuse-k8s  
helm repo update

## check if already installed
helm status ${LANGFUSE_DEPLOYMENT_NAME} -n ${LANGFUSE_K8S_NAMESPACE} > /dev/null 2>&1
if [ $? -ne 0 ]; then
    ## Install if not present
    helm install ${LANGFUSE_DEPLOYMENT_NAME} langfuse/langfuse -n ${LANGFUSE_K8S_NAMESPACE} -f values.yaml --wait
else 
    ## Update if present
    helm upgrade ${LANGFUSE_DEPLOYMENT_NAME} langfuse/langfuse -n ${LANGFUSE_K8S_NAMESPACE} -f values.yaml --wait
fi

kill $PROXY_PID