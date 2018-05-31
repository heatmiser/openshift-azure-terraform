#!/bin/bash

echo $(date) " - Starting OpenShift w/ CRI-O Deploy Script"

set -e

curruser=$(ps -o user= -p $$ | awk '{print $1}')
echo "Executing script as user: $curruser"
echo "args: $*"

export SUDOUSER=$1
export PASSWORD="$2"
export MASTER=$3
export MASTERPUBLICIPHOSTNAME=$4
export MASTERPUBLICIPADDRESS=$5
export INFRA=$6
export NODE=$7
export NODECOUNT=$8
export INFRACOUNT=$9
export MASTERCOUNT=${10}
export ROUTING=${11}
export REGISTRYSA=${12}
export ACCOUNTKEY="${13}"
export METRICS=${14}
export LOGGING=${15}
export TENANTID=${16}
export SUBSCRIPTIONID=${17}
export AADCLIENTID=${18}
export AADCLIENTSECRET="${19}"
export RESOURCEGROUP=${20}
export LOCATION=${21}
export COCKPIT=${22}
export AZURE=${23}
export STORAGEKIND=${24}
export CRS=${25}
export CRSAPP=${26}
export CRSAPPCOUNT=${27}
export CRSREG=${28}
export CRSREGCOUNT=${29}
export CRSDISKCOUNT=${30}

export BASTION=$(hostname)

function DiskDev () {
    local Rest Letters=defghijklmnopqrstuvwxyz
    Rest=${Letters#*$1}
    echo /dev/sd${Rest:$1:1}
}

function azclilogin () {
  for i in $(seq 1 5); do [ $i -gt 1 ] && sleep 15; subid=$(az login --service-principal -u $1 -p $2 --tenant $3 | jq '.[]| .id' | tr -d '"') && s=0 && break || s=$?; done; (exit $s)
  if [ $? -eq 0 ]
      then
          echo $(date) " - az cli login successful"
      else
          echo $(date) " - az cli login unsuccessful after 5 attempts - exiting"
          exit 13
  fi
  if [ "$subid" == "$4" ]
      then
          echo $(date) " - az credentials match "
      else
          echo $(date) " - az credentials do not match - exiting"
          az logout
          exit 13
  fi
}

function azclilogout () {
  az logout
}

# Note that all gluster systems for either app and/or registry storage need to be up and running for this function
# to be able to properly retrieve the actual IP assignments for both front end and back end NICs
function getIp () {
    ipaddy=$(az vm nic show --resource-group $1 --vm-name $2 --nic $3 | jq '.ipConfigurations[]' | jq '.privateIpAddress' | tr -d '"')
    echo ${ipaddy}
}

# glusterfs_hostname - A hostname (or IP address) that will be used for internal GlusterFS communication - be NIC
# glusterfs_ip - An IP address that will be used by pods to communicate with the GlusterFS node - fe NIC

# Determine if Commercial Azure or Azure Government
CLOUD="US"
export CLOUD=${CLOUD^^}

printf -v MASTERLOOP "%02d" $((MASTERCOUNT - 1))
export MASTERLOOP
printf -v INFRALOOP "%02d" $((INFRACOUNT - 1))
export INFRALOOP
printf -v NODELOOP "%02d" $((NODECOUNT - 1))
export NODELOOP
printf -v CRSAPPLOOP "%02d" $((CRSAPPCOUNT - 1))
export CRSAPPLOOP
printf -v CRSREGLOOP "%02d" $((CRSREGCOUNT - 1))
export CRSREGLOOP

# Provide current variables if needed for troubleshooting
#set -o posix ; set
echo "Command line args: $@"

if [[ $CLOUD == "US" ]]
then
  DOCKERREGISTRYYAML=dockerregistrygov.yaml
  export CLOUDNAME="AzureUSGovernmentCloud"
else
  DOCKERREGISTRYYAML=dockerregistrypublic.yaml
  export CLOUDNAME="AzurePublicCloud"

fi

# Create Master nodes grouping
echo $(date) " - Creating Master nodes grouping"

for (( c=0; c<$MASTERCOUNT; c++ ))
do
  printf -v hostnum "%02d" $c
  mastergroup="$mastergroup
$MASTER-$hostnum openshift_node_labels=\"{'region': 'master', 'zone': 'default'}\" openshift_hostname=$MASTER-$hostnum"
done

# Create Infra nodes grouping 
echo $(date) " - Creating Infra nodes grouping"

for (( c=0; c<$INFRACOUNT; c++ ))
do
  printf -v hostnum "%02d" $c
  infragroup="$infragroup
$INFRA-$hostnum openshift_node_labels=\"{'region': 'infra', 'zone': 'default'}\" openshift_hostname=$INFRA-$hostnum"
done

# Create Nodes grouping
echo $(date) " - Creating Nodes grouping"

for (( c=0; c<$NODECOUNT; c++ ))
do
  printf -v hostnum "%02d" $c
  nodegroup="$nodegroup
$NODE-$hostnum openshift_node_labels=\"{'region': 'app', 'zone': 'default'}\" openshift_hostname=$NODE-$hostnum"
done

# Create gluster disk device list
currentdisk=$(DiskDev 0)
devicelist="\"$currentdisk\""
for (( c=1; c<$CRSDISKCOUNT; c++ ))
do
  currentdisk=$(DiskDev $c)
  devicelist="$devicelist, \"$currentdisk\""
done

# Create Gluster App & Reg Nodes groupings
# Populate actual private DHCP IP assignment for backend Gluster subnet
if [[ $CRS == "true" ]]
then
    echo $(date) " - Creating CRS Apps cluster grouping"
    azclilogin $AADCLIENTID $AADCLIENTSECRET $TENANTID $SUBSCRIPTIONID
    for (( c=0; c<$CRSAPPCOUNT; c++ ))
    do
      printf -v hostnum "%02d" $c
      fenicip=$(getIp $RESOURCEGROUP $CRSAPP-$hostnum $CRSAPP-fe-nic$hostnum)
      benicip=$(getIp $RESOURCEGROUP $CRSAPP-$hostnum $CRSAPP-be-nic$hostnum)
      crsappgroup="$crsappgroup
$CRSAPP-$hostnum glusterfs_ip=$fenicip glusterfs_hostname=$benicip glusterfs_devices='[ $devicelist ]'"
    done

    for (( c=0; c<$CRSREGCOUNT; c++ ))
    do
      printf -v hostnum "%02d" $c
      fenicip=$(getIp $RESOURCEGROUP $CRSREG-$hostnum $CRSREG-fe-nic$hostnum)
      benicip=$(getIp $RESOURCEGROUP $CRSREG-$hostnum $CRSREG-be-nic$hostnum)
      crsreggroup="$crsreggroup
$CRSREG-$hostnum glusterfs_ip=$fenicip glusterfs_hostname=$benicip glusterfs_devices='[ $devicelist ]'"
    done
    azclilogout
fi

# Setting the default openshift_cloudprovider_kind if Azure enabled
if [[ $AZURE == "true" ]]
then
	export CLOUDKIND="openshift_cloudprovider_kind=azure"
fi

# Create Ansible Hosts File
echo $(date) " - Create Ansible Hosts file"

cat > inventory_file.out <<EOF
# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
nodes
etcd
master00
EOF
if [[ $CRS == "true" ]]
then
cat >> inventory_file.out <<EOF
glusterfs
glusterfs_registry
EOF
fi
cat >> inventory_file.out <<EOF
new_nodes

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
ansible_ssh_user=$SUDOUSER
ansible_become=yes
openshift_install_examples=true
deployment_type=openshift-enterprise
openshift_release=v3.9
docker_udev_workaround=True
openshift_use_dnsmasq=true
openshift_master_default_subdomain=$ROUTING
openshift_override_hostname_check=true
osm_use_cockpit=${COCKPIT}
os_sdn_network_plugin_name='redhat/openshift-ovs-multitenant'
openshift_master_api_port=443
openshift_master_console_port=443
osm_default_node_selector='region=app'
openshift_disable_check=memory_availability,docker_image_availability,docker_storage
$CLOUDKIND

# Enable cri-o
openshift_use_crio=true
#openshift_crio_enable_docker_gc=true
#oreg_url=registry.access.redhat.com/openshift3/ose-${component}:${version}
openshift_crio_systemcontainer_image_override=registry.access.redhat.com/openshift3/cri-o:v3.9

# default selectors for router and registry services
openshift_router_selector='region=infra'
openshift_registry_selector='region=infra'

# Deploy Service Catalog
openshift_enable_service_catalog=false

# template_service_broker_install=false
template_service_broker_selector={"region":"infra"}

# Type of clustering being used by OCP
openshift_master_cluster_method=native

# Addresses for connecting to the OpenShift master nodes
openshift_master_cluster_hostname=$MASTERPUBLICIPHOSTNAME
openshift_master_cluster_public_hostname=$MASTERPUBLICIPHOSTNAME
openshift_master_cluster_public_vip=$MASTERPUBLICIPADDRESS

# Enable HTPasswdPasswordIdentityProvider
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]

EOF
if [[ $CRS != "true" ]]
then
cat >> inventory_file.out <<EOF
# Setup metrics
openshift_metrics_install_metrics=false
openshift_metrics_start_cluster=true
openshift_metrics_hawkular_nodeselector={"region":"infra"}
openshift_metrics_cassandra_nodeselector={"region":"infra"}
openshift_metrics_heapster_nodeselector={"region":"infra"}
openshift_hosted_metrics_public_url=https://metrics.$ROUTING/hawkular/metrics

# Setup logging
openshift_logging_install_logging=false
openshift_logging_fluentd_nodeselector={"logging":"true"}
openshift_logging_es_nodeselector={"region":"infra"}
openshift_logging_kibana_nodeselector={"region":"infra"}
openshift_logging_curator_nodeselector={"region":"infra"}
openshift_master_logging_public_url=https://kibana.$ROUTING
openshift_logging_master_public_url=https://$MASTERPUBLICIPHOSTNAME:443

EOF
fi
if [[ $CRS == "true" ]]
then
cat >> inventory_file.out <<EOF
# registry
openshift_hosted_registry_replicas=3
openshift_registry_selector="role=infra"
openshift_hosted_registry_storage_kind=glusterfs
openshift_hosted_registry_storage_volume_size=500Gi

# CRS storage for applications
openshift_storage_glusterfs_namespace=app-storage
openshift_storage_glusterfs_is_native=false
openshift_storage_glusterfs_block_deploy=false
openshift_storage_glusterfs_storageclass=true
openshift_storage_glusterfs_heketi_is_native=true
openshift_storage_glusterfs_heketi_executor=ssh
openshift_storage_glusterfs_heketi_ssh_port=22
openshift_storage_glusterfs_heketi_ssh_user=root
openshift_storage_glusterfs_heketi_ssh_sudo=false
openshift_storage_glusterfs_heketi_ssh_keyfile="/root/.ssh/id_rsa"

# CRS storage for OpenShift infrastructure
openshift_storage_glusterfs_registry_block_deploy=true
openshift_storage_glusterfs_registry_block_host_vol_create=true    
openshift_storage_glusterfs_registry_block_host_vol_size=1000   
openshift_storage_glusterfs_registry_block_storageclass=true
openshift_storage_glusterfs_registry_block_storageclass_default=true
openshift_storage_glusterfs_registry_heketi_is_native=true
openshift_storage_glusterfs_registry_heketi_executor=ssh
openshift_storage_glusterfs_registry_heketi_ssh_port=22
openshift_storage_glusterfs_registry_heketi_ssh_user=root
openshift_storage_glusterfs_registry_heketi_ssh_sudo=false
openshift_storage_glusterfs_registry_heketi_ssh_keyfile="/root/.ssh/id_rsa"

openshift_storageclass_default=false

EOF
fi
cat >> inventory_file.out <<EOF
# host group for masters
[masters]
$MASTER-[00:${MASTERLOOP}]

# host group for etcd
[etcd]
$MASTER-[00:${MASTERLOOP}] 

[master00]
$MASTER-00

# host group for nodes
[nodes]
$mastergroup
$infragroup
$nodegroup

EOF
if [[ $CRS == "true" ]]
then
cat >> inventory_file.out <<EOF
[glusterfs]
$crsappgroup

[glusterfs_registry]
$crsreggroup
EOF
fi
cat >> inventory_file.out <<EOF

# host group for adding new nodes
[new_nodes]
EOF

if [ $METRICS == "true" ]
then
	echo $(date) "- Deploying Metrics"
	if [ $AZURE == "true" -a $CRS != "true" ]
	then
		echo "Azure on and CRS off"
	fi	
	if [ $AZURE != "true" -a $CRS != "true" ]
  then
		echo "Azure off and CRS off"
	fi
	if [ $CRS == "true" ]
	then
		echo "Update ansible inventory file and deploying Metrics..."
	fi

	if [ $? -eq 0 ]
	then
	    echo $(date) " - Metrics configuration completed successfully"
	else
	    echo $(date) " - Metrics configuration failed"
	    exit 11
	fi
fi
