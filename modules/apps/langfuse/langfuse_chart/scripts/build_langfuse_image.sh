#!/bin/bash

set -e -o pipefail

cleanup_on_error() {
    echo "An error occurred. Performing cleanup..."
    # Add your cleanup commands here
    rm -rf ~/langfuse
    # podman system prune --all --volumes --force && podman rmi --all
}

trap cleanup_on_error ERR


# get info from the instance metadata
export REGION=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".region")
export COMPARTMENT_ID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".compartmentId")
export TENANCY_ID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".tenantId")
export INSTANCE_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".id")
export DEPLOY_ID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".metadata.deploy_id")
export CLUSTER_ID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".metadata.cluster_id")
export HELM_CHART_VERSION=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".metadata.langfuse_helm_chart_version")
export TENANCY_NAMESPACE=$(oci --auth instance_principal os ns get | jq -r ".data")
export PLATFORM=$(podman system info --format json | jq .version.OsArch)
export ARCH=$(podman system info --format json | jq -r .host.arch)


# cache all build layers (faster if running multiple times, for debugging for example)
export BUILDAH_LAYERS=true
# Pull, patch and build Langfuse project
rm -rf langfuse
git clone https://github.com/langfuse/langfuse

pushd langfuse

# get latest version tag for the repo
# export LANGFUSE_VERSION=$(git tag --sort=v:refname | tail -1)
# get app version from chart version
export LANGFUSE_VERSION=$(helm show chart langfuse/langfuse --version ${HELM_CHART_VERSION} | grep appVersion | awk '{print $2}')

# checkout latest tag branch
git checkout "v${LANGFUSE_VERSION}"

## patch Langfuse for IDCS. That requires installing the JS dependencies, patching and updating the lock file

# add override of the openid-client package (which is a 3rd party dependency of NextJs Auth)
cat package.json | jq '.pnpm.overrides += {"openid-client": "5.6.5"}' > package.new.json
mv package.new.json package.json
jq '.devDependencies."release-it" = "^19.0.5"' package.json > package.new.json
mv package.new.json package.json

# add follow-redirects package
pnpm add follow-redirects@^1.15.11 -w

cat package.json

# install node modules locally so we can patch openid-client and update the package json to build the container image from lock file
pnpm install --no-frozen-lockfile


# get the location of the temporary openid-client module
export TMP_FOLDER=$(pnpm patch openid-client@5.6.5 | grep "pnpm patch-commit" | awk -F" " '{print $3}' | tr -d "'")

# patch the code of the openid-client to allow for 302 redirects to work (used by IDCS)
sed -i '/const http = /d' ${TMP_FOLDER}/lib/helpers/request.js
sed -i '/const https = /d' ${TMP_FOLDER}/lib/helpers/request.js
sed -i "5i\const { http, https } = require('follow-redirects');" ${TMP_FOLDER}/lib/helpers/request.js

# commit the openid-client patch
pnpm patch-commit ${TMP_FOLDER}

## update the lock file
pnpm update

# clean up the node_modules
rm -rf node_modules

export VERSION=${LANGFUSE_VERSION:-latest}

## push image to repo
## Get registry repo token and docker login again to the repo as token may have expried by then
oci --auth instance_principal raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | podman login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin


## Check if repo exists or create it
podman manifest inspect ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse \
|| oci --auth instance_principal artifacts container repository create \
    --compartment-id ${COMPARTMENT_ID} \
    --display-name ${DEPLOY_ID}/langfuse \
    --is-public true \
|| echo "already exists"

# build and publish the LangFuse container image
podman build --ulimit=nofile=65535:65535 --platform=${PLATFORM} --shm-size=10G -t ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse:${VERSION} --build-arg NEXT_PUBLIC_BASE_PATH=/langfuse -f ./web/Dockerfile .

## push image to repo
## Get registry repo token and docker login again to the repo as token may have expried by then
oci --auth instance_principal raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | podman login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

podman push ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse:${VERSION}

# get image by SHA
export LANGFUSE_IMAGE=$(podman inspect --format='{{index .RepoDigests 0}}' ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse:${VERSION})

popd
