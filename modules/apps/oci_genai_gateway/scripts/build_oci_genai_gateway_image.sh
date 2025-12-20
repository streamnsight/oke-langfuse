#!/bin/bash

set -e -o pipefail

cleanup_on_error() {
    echo "An error occurred. Performing cleanup..."
    # Add your cleanup commands here
    rm -rf ~/OCI_GenAI_access_gateway
}

trap cleanup_on_error ERR

# get info from the instance metadata
export REGION=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".region")
export COMPARTMENT_ID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".compartmentId")
export TENANCY_ID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".tenantId")
export INSTANCE_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".id")
export DEPLOY_ID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".metadata.deploy_id")
export TENANCY_NAMESPACE=$(oci --auth instance_principal os ns get | jq -r ".data")
export PLATFORM=$(podman system info --format json | jq .version.OsArch)
export ARCH=$(podman system info --format json | jq -r .host.arch)

set -x 

# clone the OCI_GenAI_access_gateway repo
rm -rf OCI_GenAI_access_gateway
git clone https://github.com/jin38324/OCI_GenAI_access_gateway.git

pushd OCI_GenAI_access_gateway
# checkout known tag (this repo is not very good at testing and it is best to stay with a known working version)
git checkout ${OCI_GENAI_GATEWAY_TAG:-581e3cb7150404d80b35f7875f0d28d1510d6de8}

ls -lah

## Get registry repo token and docker login again to the repo as token may have expried by then
oci --auth instance_principal raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | podman login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

## check if container repo exists or create it
podman manifest inspect ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/oci-genai-gateway \
|| oci --auth instance_principal artifacts container repository create \
    --compartment-id ${COMPARTMENT_ID} \
    --display-name ${DEPLOY_ID}/oci-genai-gateway \
    --is-public false \
|| echo "already exists"

# build for this platform. Note we use the same compute image as the OKE nodes for this instance, so we're building for the OKE platform being deployed.
podman build --platform=${PLATFORM} -t ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/oci-genai-gateway:oci .

## push image to repo
## Get registry repo token and docker login again to the repo as token may have expried by then
oci --auth instance_principal raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | podman login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

podman push ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/oci-genai-gateway:oci

popd
# clean up
rm -rf OCI_GenAI_access_gateway
