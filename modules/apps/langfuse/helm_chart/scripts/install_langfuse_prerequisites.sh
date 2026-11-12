#!/bin/bash
## Copyright © 2022-2026, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

set -euo pipefail

chart_version=${1:?Pass the Langfuse Helm chart version}
case "$chart_version" in
    1.*)
        echo "Langfuse chart $chart_version does not require the ClickHouse operator."
        exit 0
        ;;
    2.*) ;;
    *)
        echo "Unsupported Langfuse chart version '$chart_version'; review its prerequisites." >&2
        exit 1
        ;;
esac

# The operator's webhooks use cert-manager certificates.
kubectl wait --for=condition=Established --timeout=120s \
    crd/certificates.cert-manager.io crd/issuers.cert-manager.io
kubectl --namespace cert-manager wait --for=condition=Available --timeout=120s \
    deployment/cert-manager deployment/cert-manager-webhook deployment/cert-manager-cainjector

helm upgrade --install clickhouse-operator oci://ghcr.io/clickhouse/clickhouse-operator-helm \
    --version 0.0.8 --namespace clickhouse-operator --create-namespace \
    --wait --timeout 5m

kubectl wait --for=condition=Established --timeout=120s \
    crd/clickhouseclusters.clickhouse.com crd/keeperclusters.clickhouse.com
kubectl --namespace clickhouse-operator wait --for=condition=Available --timeout=120s \
    deployment --selector app.kubernetes.io/instance=clickhouse-operator

echo "Langfuse chart $chart_version prerequisites are ready."
