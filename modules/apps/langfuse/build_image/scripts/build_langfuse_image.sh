#!/bin/bash
## Copyright © 2022-2026, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

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
export CLUSTER_COMPARTMENT_ID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".metadata.cluster_compartment_id")
export HELM_CHART_VERSION=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".metadata.langfuse_helm_chart_version")
export TENANCY_NAMESPACE=$(oci --auth instance_principal os ns get | jq -r ".data")
export PLATFORM=$(podman system info --format json | jq .version.OsArch)
export ARCH=$(podman system info --format json | jq -r .host.arch)


# get latest version tag for the repo
# export LANGFUSE_VERSION=$(git tag --sort=v:refname | tail -1)
# get app version from chart version
export LANGFUSE_VERSION=$(helm show chart langfuse/langfuse --version ${HELM_CHART_VERSION} | grep appVersion | awk '{print $2}')
echo "Langfuse version: $LANGFUSE_VERSION"

export VERSION=${LANGFUSE_VERSION:-latest}
echo "Langfuse version: $VERSION"

## Get registry repo token and docker login again to the repo as token may have expried by then
oci --auth instance_principal raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | podman login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

## Check if repo exists or create it
podman manifest inspect ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse \
|| oci --auth instance_principal artifacts container repository create \
    --compartment-id ${CLUSTER_COMPARTMENT_ID} \
    --display-name ${DEPLOY_ID}/langfuse \
    --is-public false \
|| echo "already exists"

podman manifest inspect ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse-worker \
|| oci --auth instance_principal artifacts container repository create \
    --compartment-id ${CLUSTER_COMPARTMENT_ID} \
    --display-name ${DEPLOY_ID}/langfuse-worker \
    --is-public false \
|| echo "already exists"

BUILD_LANGFUSE_IMAGE=1
if podman pull ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse:${VERSION} > /dev/null 2>&1; then
    echo "langfuse Image found in the remote repository. "
    BUILD_LANGFUSE_IMAGE=0
else
    echo "langfuse Image not found, building image..."
fi

BUILD_LANGFUSE_WORKER_IMAGE=1
if podman pull ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse-worker:${VERSION} > /dev/null 2>&1; then
    echo "langfuse-worker Image found in the remote repository. "
    BUILD_LANGFUSE_WORKER_IMAGE=0
else
    echo "langfuse-worker Image not found, building image..."
fi

if [ "$BUILD_LANGFUSE_IMAGE" -eq 0 && "$BUILD_LANGFUSE_WORKER_IMAGE" -eq 0 ]; then
    echo "Both images found, skipping build"
    exit 0
fi

# cache all build layers (faster if running multiple times, for debugging for example)
export BUILDAH_LAYERS=true
# Pull, patch and build Langfuse project
rm -rf langfuse
git clone https://github.com/langfuse/langfuse --quiet

pushd langfuse


# checkout latest tag branch
git checkout "v${LANGFUSE_VERSION}"

MIN_OPENID_CLIENT_VERSION="5.6.5"
OPENID_CLIENT_RANGE="^${MIN_OPENID_CLIENT_VERSION}"

resolve_openid_client_version() {
    { pnpm list openid-client -r --depth 10 --json 2>/dev/null || true; } \
        | jq -r '
            .. | objects |
            (
                .dependencies?."openid-client"?.version?,
                (select(.name? == "openid-client") | .version?)
            ) |
            select(. != null)
        ' \
        | sort -V \
        | tail -1
}

version_lt() {
    local actual="$1"
    local minimum="$2"

    [ -n "$actual" ] || return 0
    [ "$actual" != "$minimum" ] && [ "$(printf '%s\n%s\n' "$actual" "$minimum" | sort -V | head -1)" = "$actual" ]
}

update_pnpm_workspace_override() {
    local package_name="$1"
    local package_version="$2"
    local tmp_file

    tmp_file="$(mktemp)"
    awk -v key="$package_name" -v value="$package_version" '
        function is_root_line(line) {
            return line !~ /^[[:space:]]/
        }

        function write_override_if_missing() {
            if (in_overrides && !key_written) {
                print "  " key ": " value
                key_written = 1
            }
        }

        BEGIN {
            in_overrides = 0
            overrides_found = 0
            key_written = 0
        }

        /^overrides:[[:space:]]*$/ {
            overrides_found = 1
            in_overrides = 1
            print
            next
        }

        {
            if (in_overrides) {
                if (is_root_line($0) && $0 !~ /^$/ && $0 !~ /^#/) {
                    write_override_if_missing()
                    in_overrides = 0
                } else if ($0 ~ "^[[:space:]]+" key ":[[:space:]]*") {
                    print "  " key ": " value
                    key_written = 1
                    next
                }
            }
            print
        }

        END {
            if (in_overrides) {
                write_override_if_missing()
            } else if (!overrides_found) {
                print "overrides:"
                print "  " key ": " value
            }
        }
    ' pnpm-workspace.yaml > "$tmp_file"
    mv "$tmp_file" pnpm-workspace.yaml
}

ensure_openid_client_override() {
    if [ -f pnpm-workspace.yaml ]; then
        echo "Ensuring pnpm-workspace.yaml override for openid-client ${OPENID_CLIENT_RANGE}" >&2
        update_pnpm_workspace_override "openid-client" "$OPENID_CLIENT_RANGE"
    else
        echo "Ensuring legacy package.json pnpm override for openid-client ${OPENID_CLIENT_RANGE}" >&2
        jq --arg version "$OPENID_CLIENT_RANGE" \
            '.pnpm.overrides["openid-client"] = $version' \
            package.json > package.new.json
        mv package.new.json package.json
    fi
}

ensure_supported_openid_client() {
    local openid_client_version

    openid_client_version="$(resolve_openid_client_version)"
    echo "Resolved openid-client version: ${openid_client_version:-missing}" >&2

    if [ -z "$openid_client_version" ] || version_lt "$openid_client_version" "$MIN_OPENID_CLIENT_VERSION"; then
        ensure_openid_client_override
        pnpm install --no-frozen-lockfile --loglevel=warn
        openid_client_version="$(resolve_openid_client_version)"
        echo "Resolved openid-client version after override: ${openid_client_version:-missing}" >&2
    fi

    if [ -z "$openid_client_version" ] || version_lt "$openid_client_version" "$MIN_OPENID_CLIENT_VERSION"; then
        echo "openid-client must resolve to >= ${MIN_OPENID_CLIENT_VERSION}; got '${openid_client_version:-missing}'" >&2
        exit 1
    fi

    printf '%s\n' "$openid_client_version"
}


if [ "$BUILD_LANGFUSE_IMAGE" -eq 1 ]; then
    ## patch Langfuse for IDCS. That requires installing the JS dependencies, patching and updating the lock file

    jq '.devDependencies."release-it" = "^19.0.5"' package.json > package.new.json
    mv package.new.json package.json

    # add follow-redirects package
    pnpm add follow-redirects@^1.16.0 -w

    cat package.json

    # install node modules locally so we can patch openid-client and update the package json to build the container image from lock file
    pnpm install --no-frozen-lockfile --loglevel=warn

    export OPENID_CLIENT_VERSION
    OPENID_CLIENT_VERSION="$(ensure_supported_openid_client)"
    echo "Patching openid-client version: ${OPENID_CLIENT_VERSION}"

    # get a deterministic location for the temporary openid-client module
    export TMP_FOLDER
    TMP_FOLDER="$(mktemp -d)"
    pnpm patch "openid-client@${OPENID_CLIENT_VERSION}" --edit-dir "${TMP_FOLDER}"

    # patch the code of the openid-client to allow for 302 redirects to work (used by IDCS)
    REQUEST_JS="${TMP_FOLDER}/lib/helpers/request.js"
    if [ ! -f "$REQUEST_JS" ]; then
        echo "openid-client@${OPENID_CLIENT_VERSION} does not expose lib/helpers/request.js; patch needs review" >&2
        exit 1
    fi
    sed -i '/const http = /d' "$REQUEST_JS"
    sed -i '/const https = /d' "$REQUEST_JS"
    sed -i "5i\const { http, https } = require('follow-redirects');" "$REQUEST_JS"

    # commit the openid-client patch
    pnpm patch-commit "${TMP_FOLDER}"

    ## update the lock file
    pnpm install --no-frozen-lockfile --loglevel=warn

    # clean up the node_modules
    rm -rf node_modules

    # build and publish the LangFuse container image
    podman build -q --ulimit=nofile=65535:65535 --platform=${PLATFORM} --shm-size=10G -t ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse:${VERSION} --build-arg NEXT_PUBLIC_BASE_PATH=/langfuse -f ./web/Dockerfile .

    ## push image to repo
    ## Get registry repo token and docker login again to the repo as token may have expried by then
    oci --auth instance_principal raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | podman login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

    podman push -q ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse:${VERSION}

    # get image by SHA
    export LANGFUSE_IMAGE=$(podman inspect --format='{{index .RepoDigests 0}}' ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse:${VERSION})

fi

if [ "$BUILD_LANGFUSE_WORKER_IMAGE" -eq 1 ]; then

    # build and publish the LangFuse worker container image
    podman build -q --ulimit=nofile=65535:65535 --platform=${PLATFORM} --shm-size=10G -t ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse-worker:${VERSION} --build-arg NEXT_PUBLIC_BASE_PATH=/langfuse -f ./worker/Dockerfile .

    ## push image to repo
    ## Get registry repo token and docker login again to the repo as token may have expried by then
    oci --auth instance_principal raw-request --http-method GET --target-uri https://${REGION}.ocir.io/20180419/docker/token | jq -r .data.token | podman login ${REGION}.ocir.io -u BEARER_TOKEN --password-stdin

    podman push -q ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse-worker:${VERSION}

    # get image by SHA
    export LANGFUSE_IMAGE=$(podman inspect --format='{{index .RepoDigests 0}}' ${REGION}.ocir.io/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse-worker:${VERSION})
fi

popd
