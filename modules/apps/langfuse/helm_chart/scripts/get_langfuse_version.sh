#!/bin/bash

# Exit if any of the intermediate steps fail
set -e +x -o pipefail 

# Extract "foo" and "baz" arguments from the input into
# FOO and BAZ shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "LANGFUSE_HELM_CHART_VERSION=\(.langfuse_helm_chart_version)"')"

helm repo add langfuse https://langfuse.github.io/langfuse-k8s >/dev/null 2>&1
helm repo update >/dev/null 2>&1
LANGFUSE_VERSION=$(helm show chart langfuse/langfuse --version ${LANGFUSE_HELM_CHART_VERSION} | grep appVersion | awk '{print $2}')

# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
# , "private_key_secret_ocid":"$secret_ocid"
jq -n --arg LANGFUSE_VERSION "$LANGFUSE_VERSION" '{"langfuse_version":$LANGFUSE_VERSION}'