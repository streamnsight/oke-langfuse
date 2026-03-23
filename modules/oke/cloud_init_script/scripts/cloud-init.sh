#!/bin/bash
## Copyright © 2022-2026, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

oke_init_script=$(curl --fail -m 5 -H "Authorization: Bearer Oracle" -L0 http://169.254.169.254/opc/v2/instance/metadata/oke_init_script)
if [ $? -ne 0 ]; then
  oke_init_script=$(curl --fail -m 5 -g -H "Authorization: Bearer Oracle" -L0 http://[fd00:c1::a9fe:a9fe]/opc/v2/instance/metadata/oke_init_script)
fi
echo $oke_init_script | base64 --decode > /var/run/oke-init.sh
bash /var/run/oke-init.sh

echo "${docker_login_script}" | base64 --decode > /usr/local/bin/docker_login.sh
chmod +x /usr/local/bin/docker_login.sh

echo "${docker_credential_helper_script}" | base64 --decode > /usr/local/bin/docker-credential-helper-init.sh
chmod +x /usr/local/bin/docker-credential-helper-init.sh

(crontab -l 2>/dev/null; echo "*/20 * * * * root sleep \$(( \$RANDOM \% 1000 )); /usr/local/bin/docker_login.sh") | crontab -
(crontab -l 2>/dev/null; echo "@reboot /usr/local/bin/docker_login.sh") | crontab -

bash /usr/local/bin/docker-credential-helper-init.sh
systemctl restart kubelet
systemctl daemon-reload
