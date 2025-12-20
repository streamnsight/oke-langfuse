#!/bin/bash
set -e
set -o pipefail

cred_helper_call() {
    ocir_url=$1
    targetUri="https://$ocir_url/20180419/docker/token"
    token_str=`oci raw-request --auth instance_principal --http-method GET --target-uri $targetUri | jq -r .data.token`
}

ocir_login () {
    ocir_url=$1
    if [ ! -s /var/lib/kubelet/config.json ]; then
        echo "config.json file not found. populating it"
        echo '{"auths": {}}' > /var/lib/kubelet/config.json
    fi
    echo "Logging into $ocir_url"

    max_tries=2
    count=0
    while [  $count -lt $max_tries ]; do
        cred_helper_call "$ocir_url" && break
        echo "retrying token call to ocir"
        let count=count+1
    done

    if [ "$count" -gt $max_tries ];then
        echo "call to cred helper failed"
        return 1
    fi
    echo "received token from ocir"

    output_str=$(echo -n BEARER_TOKEN:$token_str | base64 -w 0)
    url_auth_json="{ \"auth\": \"$output_str\"}"

    config=$(cat /var/lib/kubelet/config.json | jq --arg ocir_url "$ocir_url" --argjson url_auth_json "$url_auth_json" '.auths += {($ocir_url): $url_auth_json }')
    echo "$config" > /var/lib/kubelet/config.json
    # try to write to docker for backwards compatibility
    echo "$config" > /root/.docker/config.json || true
}

instanceMetadata=$(curl -L -H 'Authorization: Bearer Oracle' http://169.254.169.254/opc/v2/instance/regionInfo)
realm=$(echo $instanceMetadata | jq -r '.realmKey')
domain=$(echo $instanceMetadata | jq -r '.realmDomainComponent')
regionName=$(echo $instanceMetadata | jq -r '.regionIdentifier')
regionCode=$(echo $instanceMetadata | jq -r '.regionKey' | tr '[:upper:]' '[:lower:]')
if [ $realm = "oc1" ]; then
    # we need to log into the airport code and the long name
    # for backwards compatibility reasons
    ocir_login "$regionName.ocir.io"
    ocir_login "$regionCode.ocir.io"
else
    ocir_login "ocir.$regionName.oci.$domain"
fi
echo Finished Docker Credential Helper Token Get Provisioning
