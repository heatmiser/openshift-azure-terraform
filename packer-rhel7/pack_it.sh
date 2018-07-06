#!/bin/bash

if command -v packer 2>/dev/null; then
    export PACKER=$(command -v packer)
elif command -v ./packer 2>/dev/null; then
    export PACKER=$(command -v ./packer)
else
    echo "packer not found, downloading locally..."
    wget https://releases.hashicorp.com/packer/1.2.4/packer_1.2.4_linux_amd64.zip
    unzip packer_1.2.4_linux_amd64.zip
    if command -v ./packer 2>/dev/null; then
        export PACKER=$(command -v ./packer)
    else
        echo "Something went wrong, exiting..."
        exit 1
    fi
fi

rhn_username_org=$(grep rhn_user ../env-dev/03rhn.tfvars | awk '{print $3}' | tr -d '"')
rhn_password_act_key=$(grep rhn_passwd ../env-dev/03rhn.tfvars | awk '{print $3}' | tr -d '"')
rhn_pool_id=$(grep rhn_poolid ../env-dev/03rhn.tfvars | awk '{print $3}' | tr -d '"')

$PACKER build \
    -var 'rhn_username_org=$rhn_username_org' \
    -var 'rhn_password_act_key=$rhn_password_act_key' \
    -var 'rhn_password_act_key=$rhn_pool_id' \
    -only=rhel-7-cloud-azure \
    rhel7.json
