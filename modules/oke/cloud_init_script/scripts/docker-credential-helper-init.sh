#!/bin/bash
## Copyright © 2022-2026, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

set -e -o pipefail

if ! oci -v; then
    . /etc/os-release
    case "${ID}:${VERSION_ID%%.*}" in
        ol:8)
            dnf -y install oraclelinux-developer-release-el8
            dnf -y install python36-oci-cli
            ;;
        ol:9)
            dnf -y install oraclelinux-developer-release-el9
            dnf -y install python39-oci-cli
            ;;
        *)
            echo "Unsupported operating system for OCI CLI installation: ${ID} ${VERSION_ID}" >&2
            exit 1
            ;;
    esac
    oci -v
fi

mkdir -p /var/lib/kubelet
mkdir -p /root/.docker
# Enable bastion service
# export INSTANCE_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r ".id")
# oci compute instance update --auth instance_principal --instance-id "$INSTANCE_OCID" --agent-config <(cat <<EOF
# {
#   "pluginsConfig": [
#     {
#       "desiredState": "ENABLED",
#       "name": "Bastion"
#     }
#   ]
# }
# EOF
# )
/usr/local/bin/docker_login.sh || { echo docker login failed ; exit 1; }
