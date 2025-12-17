#!/bin/bash

set -e -o pipefail

cleanup_on_error() {
    echo "An error occurred. Performing cleanup..."
    # Add your cleanup commands here
    # rm -rf ~/langfuse
    # podman system prune --all --volumes --force && podman rmi --all
}

trap cleanup_on_error ERR

# run as root with root env
# try to increase file limit as it is an issue when building the langfuse image
REQUIRED_LIMIT=65535
CURRENT_LIMIT=$(ulimit -n)

if (( CURRENT_LIMIT < REQUIRED_LIMIT )); then
    sudo -i <<'AS_SU'
echo -e "\nDefaultLimitNOFILE=65535" >> /etc/systemd/user.conf
echo -e "\nDefaultLimitNOFILE=65535" >> /etc/systemd/system.conf
echo -e "\n* hard nofile 65535" >>  /etc/security/limits.conf
echo -e "\n* soft nofile 65535" >>  /etc/security/limits.conf
AS_SU

    # set new limits
    sudo ulimit -n -H 65535
    sudo ulimit -n -S 65535
    ulimit -n -H 65535
    ulimit -n -S 65535
fi 

# validate it worked
ulimit -a

# install dependencies
## OCI CLI

sudo yum install -y podman git curl jq sed python3.12 python3.12-pip
python3.12 -m pip install oci-cli==3.71.1
# there is a bug in 3.71.2 that prevents auth with intance principal. TODO: update version when bug is fixed

# install nvm to install node
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.nvm/nvm.sh
# install node v24
nvm install v24

# install pnpm
curl -fsSL https://get.pnpm.io/install.sh | sh -
source ~/.bashrc


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
# grow the file system. Building the LangFuse image requires over 40GB
sudo /usr/libexec/oci-growfs -y

# Install kubectl to run remote-exec script for secrets
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
# TODO verify the binary
chmod +x kubectl
mv -f kubectl ~/.local/bin/kubectl

set -x 

# install helm to get default values and find version of the Langfuse image for the chart version used
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash

# install Helm chart repo
helm repo add langfuse https://langfuse.github.io/langfuse-k8s
helm repo update




# get a fresh kubeconfig
rm -f $HOME/.kube/config
oci --auth instance_principal ce cluster create-kubeconfig --cluster-id ${CLUSTER_ID} --file $HOME/.kube/config --region ${REGION} --token-version 2.0.0  --kube-endpoint PRIVATE_ENDPOINT
# edit the kubeconfig to use instance principal auth
sed -i '23i\      - --auth' $HOME/.kube/config
sed -i '24i\      - instance_principal' $HOME/.kube/config

# check it works
kubectl get pods -A 

kubectl get namespace langfuse || kubectl create namespace langfuse

# Schedule termination of this instance
