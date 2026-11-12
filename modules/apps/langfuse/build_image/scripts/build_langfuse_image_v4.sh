#!/bin/bash
## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

set -euo pipefail

metadata=$(curl --fail --silent --show-error -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/)
REGION=$(jq -er '.region' <<< "$metadata")
CLUSTER_COMPARTMENT_ID=$(jq -er '.metadata.cluster_compartment_id' <<< "$metadata")
DEPLOY_ID=$(jq -er '.metadata.deploy_id' <<< "$metadata")
HELM_CHART_VERSION=$(jq -er '.metadata.langfuse_helm_chart_version' <<< "$metadata")

if [[ ! "$HELM_CHART_VERSION" =~ ^2\. ]]; then
    echo "The Langfuse v4 builder requires a Helm chart 2.x version; got '$HELM_CHART_VERSION'." >&2
    exit 1
fi

# Keep assignment separate from export so a failed Helm lookup stops the build.
chart=$(helm show chart langfuse/langfuse --version "$HELM_CHART_VERSION")
VERSION=$(awk '$1 == "appVersion:" {gsub(/["\047]/, "", $2); print $2}' <<< "$chart")
if [[ ! "$VERSION" =~ ^4\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
    echo "Chart $HELM_CHART_VERSION must resolve to a Langfuse v4 appVersion; got '$VERSION'." >&2
    exit 1
fi

echo "Building Langfuse $VERSION from Helm chart $HELM_CHART_VERSION (v4 builder)"
TENANCY_NAMESPACE=$(oci --auth instance_principal os ns get | jq -er '.data')
PLATFORM=$(podman system info --format json | jq -er '.version.OsArch')
REGISTRY="${REGION}.ocir.io"
WEB_IMAGE="${REGISTRY}/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse:${VERSION}"
WORKER_IMAGE="${REGISTRY}/${TENANCY_NAMESPACE}/${DEPLOY_ID}/langfuse-worker:${VERSION}"

registry_login() {
    oci --auth instance_principal raw-request --http-method GET \
        --target-uri "https://${REGISTRY}/20180419/docker/token" \
        | jq -er '.data.token | select(type == "string" and length > 0)' \
        | podman login "$REGISTRY" -u BEARER_TOKEN --password-stdin
}

registry_login
for name in langfuse langfuse-worker; do
    repository_id=$(oci --auth instance_principal artifacts container repository list \
        --compartment-id "$CLUSTER_COMPARTMENT_ID" --display-name "${DEPLOY_ID}/${name}" \
        --all --query 'data.items[0].id' --raw-output)
    if [ -z "$repository_id" ] || [ "$repository_id" = "null" ]; then
        oci --auth instance_principal artifacts container repository create \
            --compartment-id "$CLUSTER_COMPARTMENT_ID" \
            --display-name "${DEPLOY_ID}/${name}" --is-public false
    fi
done

build_web=true
build_worker=true
if podman pull "$WEB_IMAGE" > /dev/null 2>&1; then
    build_web=false
fi
if podman pull "$WORKER_IMAGE" > /dev/null 2>&1; then
    build_worker=false
fi
if [ "$build_web" = false ] && [ "$build_worker" = false ]; then
    echo "Both Langfuse $VERSION images already exist; skipping build."
    exit 0
fi

build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

git clone --quiet --depth 1 --branch "v${VERSION}" https://github.com/langfuse/langfuse.git "$build_dir/langfuse"
cd "$build_dir/langfuse"
export BUILDAH_LAYERS=true

if [ "$build_web" = true ]; then
    # Preserve upstream workspace overrides and patches, including its NextAuth patch.
    pnpm install --frozen-lockfile --loglevel=warn
    openid_version=$(pnpm list openid-client -r --depth 10 --json \
        | jq -r '.. | objects | (.dependencies?."openid-client"?.version?, (select(.name? == "openid-client") | .version?)) | select(. != null)' \
        | sort -V | tail -1)
    if [[ ! "$openid_version" =~ ^5\.[0-9]+\.[0-9]+$ ]]; then
        echo "The v4 redirect patch requires openid-client 5.x; resolved '${openid_version:-missing}'. Review the patch before building." >&2
        exit 1
    fi

    pnpm add follow-redirects@1.16.0 -w
    patch_dir="$build_dir/openid-client"
    pnpm patch "openid-client@${openid_version}" --edit-dir "$patch_dir"
    python3 - "$patch_dir/lib/helpers/request.js" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
for module in ("http", "https"):
    original = f"const {module} = require('{module}');"
    if source.count(original) != 1:
        raise SystemExit(f"Unexpected openid-client transport for {module}; review redirect patch")
    source = source.replace(original, f"const {{ {module} }} = require('follow-redirects');")
path.write_text(source)
PY
    pnpm patch-commit "$patch_dir"
    pnpm install --no-frozen-lockfile --loglevel=warn
    podman build -q --ulimit=nofile=65535:65535 --platform="$PLATFORM" --shm-size=10G \
        -t "$WEB_IMAGE" --build-arg NEXT_PUBLIC_BASE_PATH=/langfuse -f ./web/Dockerfile .
    registry_login
    podman push -q "$WEB_IMAGE"
fi

if [ "$build_worker" = true ]; then
    podman build -q --ulimit=nofile=65535:65535 --platform="$PLATFORM" --shm-size=10G \
        -t "$WORKER_IMAGE" --build-arg NEXT_PUBLIC_BASE_PATH=/langfuse -f ./worker/Dockerfile .
    registry_login
    podman push -q "$WORKER_IMAGE"
fi
