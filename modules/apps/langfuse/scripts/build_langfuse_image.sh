#!/bin/bash

set -x 

cd ${MODULE_PATH}

ls -lah
uname -a

## Get registry repo token and docker login to the repo
oci raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | docker login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

### clone langfuse repo
rm -rf langfuse
git clone https://github.com/langfuse/langfuse.git
pushd langfuse

## Get latest version
LATEST_TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)")
LANGFUSE_IMAGE_VERSION=${LANGFUSE_IMAGE_VERSION:-$LATEST_TAG}
echo ${LANGFUSE_IMAGE_VERSION} > ../langfuse.version

git checkout ${LANGFUSE_IMAGE_VERSION}

## check if container repo exists or create it
docker manifest inspect ${REGION}.ocir.io/${TENANCY_NAMESPACE}/langfuse \
|| oci artifacts container repository create \
    --compartment-id ${COMPARTMENT_ID} \
    --display-name langfuse \
    --is-public false


# get tags
#oci raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | xargs curl --user BEARER:I{} -X GET ${REGION}.ocir.io/${TENANCY_NAMESPACE}/v2/langfuse/tags/list


## Patch for IDCS


# build
docker buildx build -t ${REGION}.ocir.io/${TENANCY_NAMESPACE}/langfuse:${LANGFUSE_IMAGE_VERSION} --platform "linux/arm64" --build-arg NEXT_PUBLIC_BASE_PATH=/langfuse -f ./web/Dockerfile .
# this takes quite some time!


## push image to repo
## Get registry repo token and docker login again to the repo as token may have expried by then
oci raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | docker login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

docker tag ${REGION}.ocir.io/${TENANCY_NAMESPACE}/langfuse:${LANGFUSE_IMAGE_VERSION} ${REGION}.ocir.io/${TENANCY_NAMESPACE}/langfuse:latest
docker push ${REGION}.ocir.io/${TENANCY_NAMESPACE}/langfuse:${LANGFUSE_IMAGE_VERSION}
docker push ${REGION}.ocir.io/${TENANCY_NAMESPACE}/langfuse:latest

popd 
rm -rf langfuse
