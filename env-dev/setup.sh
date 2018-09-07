#!/bin/bash

envdir=$(pwd)
projectdir="$(dirname "$envdir")"
projectname="$(basename "$projectdir")"
bindir="$projectdir/bin"

if [ ! -d "$bindir" ]; then
    echo "$projectname/bin does not exist, creating..."
    mkdir "$bindir"
fi

cd "$bindir" || exit

echo "Checking for necessary tools, configuring if necessary..."

if [[ ! -f "$bindir/task" ]]; then
    echo "'task' not found, configuring..."
    #osname=$(cat /etc/os-release | grep '^NAME' | cut -f2 -d'=')
    wget https://github.com/go-task/task/releases/download/v2.0.3/task_linux_amd64.tar.gz
    wget https://github.com/go-task/task/releases/download/v2.0.3/task_linux_386.tar.gz
    tar xzvf task_linux_amd64.tar.gz task && mv task task64
    tar xzvf task_linux_386.tar.gz task && mv task task32
    rm task_linux_amd64.tar.gz task_linux_386.tar.gz
    if [[ ! -f "/lib64/ld-linux-x86-64.so.2" ]]; then
        ln -s task32 task
    else
        ln -s task64 task
    fi
fi

if [[ ! -f "$bindir/terraform" ]]; then
    echo "'terraform' not found, configuring..."
    wget https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_linux_amd64.zip
    unzip terraform_0.11.8_linux_amd64.zip
    rm terraform_0.11.8_linux_amd64.zip
fi

if [[ ! -f "$bindir/packer" ]]; then                                        
    echo "'packer' not found, configuring..."                                  
    wget https://releases.hashicorp.com/packer/1.2.5/packer_1.2.5_linux_amd64.zip
    unzip packer_1.2.5_linux_amd64.zip
    rm -f packer_1.2.5_linux_amd64.zip
fi    


if command -v jq 2>/dev/null; then
    echo "jq present, continuing..."
elif command -v ./jq 2>/dev/null; then
    echo "jq present, continuing..."
else
    echo "jq not found, configuring..."
    wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
    ln -s jq-linux64 jq
fi

if command -v qemu-img 2>/dev/null; then
    echo "qemu-img present, continuing..."
else
    echo "!!!! qemu-img not found, please install !!!!"
fi

if command -v qemu-system-x86_64 2>/dev/null; then
    echo "qemu-system-x86_64 present, continuing..."
else
    echo "!!!! qemu-system-x86_64 not found, please install !!!!"
    echo "...then, add current user as member of libvirt group(RHEL/Fedora) or"
    echo "kvm group(Ubuntu/Debian), then logout and log back in to continue..."
fi

cd "$envdir" || exit
export PATH="$bindir":$PATH

if command -v az 2>/dev/null; then
    echo "Azure CLI found, continuing..."
else
    echo "Azure CLI not found, please install and re-run setup.sh"
fi

if [[ ! -f "azcreds.json" ]]; then
    echo "Azure credentials file azcreds.json not found, please copy"
    echo "azcreds.json.sample to azcreds.json, then edit azcreds.json, supplying"
    echo "the proper Azure authentication credentials, and re-run setup.sh"
    exit 1                                                                      
fi

aad_client_id=$(cat azcreds.json | jq '.aad_client_id' | tr -d '"')
aad_client_secret=$(cat azcreds.json | jq '.aad_client_secret' | tr -d '"')
tenant_id=$(cat azcreds.json | jq '.tenant_id' | tr -d '"')

azurelogin=$(az login --service-principal --username $aad_client_id --password $aad_client_secret --tenant $tenant_id)

azureloginresult=$(echo $azurelogin | jq '.[0].state' | tr -d '"')
if [ "$azureloginresult" != "Enabled" ]; then
    echo "Azure credentials in azcreds.json are incorrect, please adjust and re-run setup.sh"
    exit 1
else
    echo "Azure credentials in azcreds.json verified, creating project.env for future env sourcing..."
fi

subscription_id=$(echo $azurelogin | jq '.[0].id' | tr -d '"')

export ARM_SUBSCRIPTION_ID=$subscription_id
export ARM_CLIENT_ID=$aad_client_id
export ARM_CLIENT_SECRET="$aad_client_secret"
export ARM_TENANT_ID=$tenant_id

# -----------------------------------------------------------
(
cat <<EOPS1
echo "Setting project environment variables..."
export PATH="$bindir":\$PATH
# Azure
export ARM_SUBSCRIPTION_ID=$subscription_id
export ARM_CLIENT_ID=$aad_client_id
export ARM_CLIENT_SECRET=$aad_client_secret
export ARM_TENANT_ID=$tenant_id

EOPS1
) > project.env
cat Taskcompletion.env >> project.env
