#!/bin/bash -xe

set -o pipefail

if ! rpm --quiet --query python36-oci-cli; then
    yum install -y python36-oci-cli
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
/var/run/docker_login.sh || { echo docker login failed ; exit 1; }