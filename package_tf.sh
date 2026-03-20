#!/bin/bash

## Copyright © 2022-2026, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl


rm -f oke-langfuse.zip
zip -rxvf oke-langfuse.zip ./* \
    -x '*/.terraform/*' \
    -x '.terraform/*' \
    -x '.github/*' \
    -x '*/tests/*' \
    -x 'tests/*' \
    -x *.tfvars \
    -x *.DS_Store \
    -x *.zip \
    -x *.locl.hcl \
    -x *.tfstate* \
    -x *.tfstate.backup \
    -x *CaCertificate-langfuse.pub
