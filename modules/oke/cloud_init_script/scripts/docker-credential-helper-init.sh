#!/bin/bash -xe

function die { echo "${@}" 1>&2 ; exit 2; }

set -o pipefail

while [ -f /root/firstboot.sh ] ; do
    echo "Waiting on firstboot to complete"
    sleep 1
done

# and check that it at least left the yum repos in a good state
if [ -z "$(yum list --quiet ansible 2>/dev/null)" ] ; then
    die "firstboot failed to properly configure yum"
fi


#yum install -y java-1.8.0-openjdk
#yum install -y docker-credential-ocir
# pip3 install oci-cli
yum install -y python36-oci-cli

mkdir -p /var/lib/kubelet
mkdir -p /root/.docker
ln -s /var/lib/kubelet/config.json /root/.docker/config.json
/root/docker_login.sh || { echo docker login failed ; exit 1; }