#!/bin/bash

## Clone the repo
rm -rf OCI_GenAI_access_gateway
git clone https://github.com/jin38324/OCI_GenAI_access_gateway.git
pushd OCI_GenAI_access_gateway

git checkout ${OCI_GENAI_GATEWAY_TAG:-581e3cb7150404d80b35f7875f0d28d1510d6de8}


## check if container repo exists or create it
docker manifest inspect ${REGION}.ocir.io/${TENANCY_NAMESPACE}/oci-genai-gateway \
|| oci artifacts container repository create \
    --compartment-id ${COMPARTMENT_ID} \
    --display-name oci-genai-gateway \
    --is-public false

docker build --platform=linux/amd64 -t ${REGION}.ocir.io/${TENANCY_NAMESPACE}/oci-genai-gateway:latest .

## push image to repo
## Get registry repo token and docker login again to the repo as token may have expried by then
oci raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | docker login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

docker push ${REGION}.ocir.io/${TENANCY_NAMESPACE}/oci-genai-gateway:latest

popd 
rm -rf langfuse