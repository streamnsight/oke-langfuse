#!/bin/bash 

set -e -o pipefail

# oci-genai-gateway default API key value
kubectl get secret oci-genai-gateway -n langfuse \
&& kubectl delete secret oci-genai-gateway -n langfuse

kubectl create secret generic oci-genai-gateway \
--namespace langfuse \
--from-literal="DEFAULT_API_KEYS"="${default_api_keys}"
