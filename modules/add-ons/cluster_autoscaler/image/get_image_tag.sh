#!/bin/bash

set -e

# extract inputs into variables
# https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external
eval "$(jq -r '@sh "kubernetes_version=\(.kubernetes_version) ocir_region=\(.ocir_region)"')"

K8S=`sed 's|v||' <<< "${kubernetes_version}"`

# Get the latest image for the k8s version:
# Lookup images tags from the container registry, 
# filter by k8s version, capture k8s and image versions, 
# order by (numeric) image version and get latest, 
# output as object as required by the external datasource.
oci raw-request --http-method GET --target-uri https://${ocir_region}.ocir.io/v2/oracle/oci-cluster-autoscaler/tags/list \
| jq --arg k ${K8S} '[ .data | .tags // [] | .[] 
    |  select( . | contains($k)) 
    | capture("(?<kv>[[:digit:]]+[.][[:digit:]]+[.][[:digit:]]+)[-](?<iv>[[:digit:]]+)") ] 
    | unique 
    | sort_by(.iv|tonumber) 
    | reverse 
    | .[0] 
    | { "image": (.kv + "-" + .iv)}'