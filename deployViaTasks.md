# openshift-azure-terraform - deploy utilities - Release 3.11
OpenShift Container Platform on Azure deployment via Terraform

## Fedora-based deploy, currently via Fedora 29

If you're going to be creating golden RHEL images to install OCP onto, you'll need to add your user to the libvirt and qemu groups:
sudo adduser $USER libvirt
sudo adduser $USER libvirt-qemu

Select or create a base directory where we will clone the openshift-azure-terraform project directory
cd to new base dir
git clone https://github.com/heatmiser/openshift-azure-terraform.git

cd openshift-azure-terraform/
git checkout release-3.11

Install Azure CLI...
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
sudo yum install azure-cli

## Azure service principal and password

If you do not an Azure service principal account and password, you will need one to continue. Login via the Azure CLI with an account that has administrator priveleges:

az login -u adminaccount@myco.onmicrosoft.com
Password: 
[
  {
    "cloudName": "AzureCloud",
    "id": "cec8dc40-d554-4128-a31a-6f1d39890ab5",
    "isDefault": true,
    "name": "Microsoft Azure",
    "state": "Enabled",
    "tenantId": "e09fe7ba-2840-4126-b83e-6f8622172287",
    "user": {
      "name": "adminaccount@myco.onmicrosoft.com",
      "type": "user"
    }
  }
]

pip3 install --user python_terraform
pip3 install --user invoke
cd cntrutil01/openshift-azure-terraform/
cd env-dev/
cp azcreds.json.sample azcreds.json
source Taskcompletion.env 
./setup.sh 