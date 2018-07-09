#!/bin/bash

#DEBUG="-debug"

if command -v packer 2>/dev/null; then
    testpacker="$(packer --help 2>&1 | grep dbname)"
    if [ "$testpacker" == "" ]; then
        export PACKER="$(command -v packer)"
    fi
fi
if [ "$PACKER" == "" ]; then
    if command -v ./packer 2>/dev/null; then
        export PACKER="$(command -v ./packer)"
    fi
fi
if [ "$PACKER" == "" ]; then
    echo "packer not found, exiting..."
    exit 1
fi
echo "Using packer: '$PACKER'"
rhn_username_org="$(grep rhn_user ../env-dev/03rhn.tfvars | awk '{print $3}' | tr -d '"')"
rhn_password_act_key="$(grep rhn_passwd ../env-dev/03rhn.tfvars | awk '{print $3}' | tr -d '"')"
rhn_pool_id="$(grep rhn_poolid ../env-dev/03rhn.tfvars | awk '{print $3}' | tr -d '"')"

echo ""
echo "Executing:"
echo ""
echo "rhn_username_org=$rhn_username_org \\"
echo "rhn_password_act_key=$rhn_password_act_key \\"
echo "rhn_pool_id=$rhn_pool_id \\"
echo "$PACKER build $DEBUG\\"
echo "    -only=rhel-7-cloud-azure \\"
echo "    rhel7.json"

rhn_username_org="$rhn_username_org" \
rhn_password_act_key="$rhn_password_act_key" \
rhn_pool_id="$rhn_pool_id" \
"$PACKER" build $DEBUG \
    -only=rhel-7-cloud-azure \
    rhel7.json
