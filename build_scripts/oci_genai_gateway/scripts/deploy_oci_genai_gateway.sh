#!/bin/bash
set -x 

cd ${MODULE_PATH}

ls -lah

## Get cluster kubeconfig
# oci ce cluster create-kubeconfig --cluster-id ${CLUSTER_ID} --file $HOME/.kube/config --region ${REGION} --token-version 2.0.0  --kube-endpoint PRIVATE_ENDPOINT --auth resource_principal

cat ../../../kubeconfig
export KUBECONFIG=../../../kubeconfig

## Clone the repo
rm -rf OCI_GenAI_access_gateway
git clone https://github.com/jin38324/OCI_GenAI_access_gateway.git
pushd OCI_GenAI_access_gateway

git checkout ${OCI_GENAI_GATEWAY_TAG:-581e3cb7150404d80b35f7875f0d28d1510d6de8}


## Get registry repo token and docker login again to the repo as token may have expried by then
oci raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | docker login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

## check if container repo exists or create it
docker manifest inspect ${REGION}.ocir.io/${TENANCY_NAMESPACE}/oci-genai-gateway \
|| oci artifacts container repository create \
    --compartment-id ${COMPARTMENT_ID} \
    --display-name oci-genai-gateway \
    --is-public false

# # install QEMU
# docker run --privileged --rm tonistiigi/binfmt --install all
# export DOCKER_BUILDKIT=1
# docker buildx create --use

# build
docker buildx build --platform "linux/arm64" -t ${REGION}.ocir.io/${TENANCY_NAMESPACE}/oci-genai-gateway:latest .

## push image to repo
## Get registry repo token and docker login again to the repo as token may have expried by then
oci raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | docker login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

docker push ${REGION}.ocir.io/${TENANCY_NAMESPACE}/oci-genai-gateway:latest

# get image by SHA
export OCI_GENAI_GATEWAY_IMAGE=$(docker inspect --format='{{index .RepoDigests 0}}' ${REGION}.ocir.io/${TENANCY_NAMESPACE}/oci-genai-gateway:latest)

popd 
rm -rf OCI_GenAI_access_gateway

## generate the manifest

eval "echo \"$(cat ./manifests/genai_gateway.Deployment.template.yaml)\"" > genai_gateway.Deployment.yaml

cat genai_gateway.Deployment.yaml


## Start SSH proxy to K8S API

ssh -o StrictHostKeyChecking=accept-new -i bastionKey.pem -N -D 127.0.0.1:1088 -p 22 ${BASTION_SESSION_ID}@host.bastion.${REGION}.oci.oraclecloud.com &
PROXY_PID=$!

export HTTP_PROXY="socks5://127.0.0.1:1088"
export HTTPS_PROXY="socks5://127.0.0.1:1088"

## deploy the manifest
# validate manifest

pip install PySocks

kubectl get pods -A

kubectl apply -f genai_gateway.Deployment.yaml --dry-run=client -o yaml
# no validation on apply this time as it fails when using the proxy
kubectl apply -n ${LANGFUSE_K8S_NAMESPACE} -f genai_gateway.Deployment.yaml --wait --validate=false

kill $PROXY_PID