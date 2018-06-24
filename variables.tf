variable "project" {
  description = "Project name, also used as Cluster Prefix used to configure domain name label and hostnames for all nodes - master, infra and node Between 1 and 20 characters"
}

variable "environment" {}
variable "env_version" {}
variable "resource_group_name" {}
variable "location" {}
variable "storage_account_name" {}
variable "key" {}
variable "container_name" {}
variable "ocp_cidr_block" {}
variable "ocp_cidrsubnet_newbits" {}
variable "crs_cidr_block" {}
variable "crs_cidrsubnet_newbits" {}
variable "images_resource_group" {}
variable "base_os_image" {}
variable "network1_module_name" {}
variable "network2_module_name" {}
variable "ocpmaster_module_name" {}
variable "ocpinfra_module_name" {}
variable "ocpnode_module_name" {}
variable "ocpcrs_app_module_name" {}
variable "ocpcrs_registry_module_name" {}
variable "ocpbastion_module_name" {}
variable "ocpopenvpn_module_name" {}
variable "singlequote" {}

variable "rhn_user" {}
variable "rhn_passwd" {}

variable "rhn_poolid" {
  default = "null"
}

variable "ocp_storage_addon_poolid" {
  default = "null"
}

variable "subscription_id" {
  description = "Subscription ID of the key vault"
}

variable "tenant_id" {
  description = "Tenant ID with access to your key vault and subscription"
}

variable "openshift_script_path" {
  description = "Local path to openshift scripts to prep nodes and install openshift origin"
}

variable "os_image" {
  description = "Select from CentOS (centos) or RHEL (rhel) for the Operating System"
  default     = "centos"
}

variable "bastion_vm_size" {
  description = "Size of the Bastion Virtual Machine. Allowed values: Standard_A4, Standard_A5, Standard_A6, Standard_A7, Standard_A8, Standard_A9, Standard_A10, Standard_A11, Standard_D1, Standard_D2, Standard_D3, Standard_D4, Standard_D11, Standard_D12, Standard_D13, Standard_D14, Standard_D1_v2, Standard_D2_v2, Standard_D3_v2, Standard_D4_v2, Standard_D5_v2, Standard_D11_v2, Standard_D12_v2, Standard_D13_v2, Standard_D14_v2, Standard_G1, Standard_G2, Standard_G3, Standard_G4, Standard_G5, Standard_D1_v2, Standard_DS2, Standard_DS3, Standard_DS4, Standard_DS11, Standard_DS12, Standard_DS13, Standard_DS14, Standard_DS1_v2, Standard_DS2_v2, Standard_DS3_v2, Standard_DS4_v2, Standard_DS5_v2, Standard_DS11_v2, Standard_DS12_v2, Standard_DS13_v2, Standard_DS14_v2, Standard_GS1, Standard_GS2, Standard_GS3, Standard_GS4, Standard_GS5"
  default     = "Standard_DS2_v2"
}

variable "master_vm_size" {
  description = "Size of the Master Virtual Machine. Allowed values: Standard_A4, Standard_A5, Standard_A6, Standard_A7, Standard_A8, Standard_A9, Standard_A10, Standard_A11, Standard_D1, Standard_D2, Standard_D3, Standard_D4, Standard_D11, Standard_D12, Standard_D13, Standard_D14, Standard_D1_v2, Standard_D2_v2, Standard_D3_v2, Standard_D4_v2, Standard_D5_v2, Standard_D11_v2, Standard_D12_v2, Standard_D13_v2, Standard_D14_v2, Standard_G1, Standard_G2, Standard_G3, Standard_G4, Standard_G5, Standard_D1_v2, Standard_DS2, Standard_DS3, Standard_DS4, Standard_DS11, Standard_DS12, Standard_DS13, Standard_DS14, Standard_DS1_v2, Standard_DS2_v2, Standard_DS3_v2, Standard_DS4_v2, Standard_DS5_v2, Standard_DS11_v2, Standard_DS12_v2, Standard_DS13_v2, Standard_DS14_v2, Standard_GS1, Standard_GS2, Standard_GS3, Standard_GS4, Standard_GS5"
  default     = "Standard_DS4_v2"
}

variable "infra_vm_size" {
  description = "Size of the Infra Virtual Machine. Allowed values: Standard_A4, Standard_A5, Standard_A6, Standard_A7, Standard_A8, Standard_A9, Standard_A10, Standard_A11,Standard_D1, Standard_D2, Standard_D3, Standard_D4,Standard_D11, Standard_D12, Standard_D13, Standard_D14,Standard_D1_v2, Standard_D2_v2, Standard_D3_v2, Standard_D4_v2, Standard_D5_v2,Standard_D11_v2, Standard_D12_v2, Standard_D13_v2, Standard_D14_v2,Standard_G1, Standard_G2, Standard_G3, Standard_G4, Standard_G5,Standard_D1_v2, Standard_DS2, Standard_DS3, Standard_DS4,Standard_DS11, Standard_DS12, Standard_DS13, Standard_DS14,Standard_DS1_v2, Standard_DS2_v2, Standard_DS3_v2, Standard_DS4_v2, Standard_DS5_v2,Standard_DS11_v2, Standard_DS12_v2, Standard_DS13_v2, Standard_DS14_v2,Standard_GS1, Standard_GS2, Standard_GS3, Standard_GS4, Standard_GS5"
  default     = "Standard_DS3_v2"
}

variable "node_vm_size" {
  description = "Size of the Node Virtual Machine. Allowed values: Standard_A4, Standard_A5, Standard_A6, Standard_A7, Standard_A8, Standard_A9, Standard_A10, Standard_A11, Standard_D1, Standard_D2, Standard_D3, Standard_D4, Standard_D11, Standard_D12, Standard_D13, Standard_D14, Standard_D1_v2, Standard_D2_v2, Standard_D3_v2, Standard_D4_v2, Standard_D5_v2, Standard_D11_v2, Standard_D12_v2, Standard_D13_v2, Standard_D14_v2, Standard_G1, Standard_G2, Standard_G3, Standard_G4, Standard_G5, Standard_D1_v2, Standard_DS2, Standard_DS3, Standard_DS4, Standard_DS11, Standard_DS12, Standard_DS13, Standard_DS14, Standard_DS1_v2, Standard_DS2_v2, Standard_DS3_v2, Standard_DS4_v2, Standard_DS5_v2, Standard_DS11_v2, Standard_DS12_v2, Standard_DS13_v2, Standard_DS14_v2, Standard_GS1, Standard_GS2, Standard_GS3, Standard_GS4, Standard_GS5"
  default     = "Standard_DS3_v2"
}

variable "gluster_vm_size" {
  description = "Size of the Gluster Virtual Machine. Allowed values: Standard_A4, Standard_A5, Standard_A6, Standard_A7, Standard_A8, Standard_A9, Standard_A10, Standard_A11, Standard_D1, Standard_D2, Standard_D3, Standard_D4, Standard_D11, Standard_D12, Standard_D13, Standard_D14, Standard_D1_v2, Standard_D2_v2, Standard_D3_v2, Standard_D4_v2, Standard_D5_v2, Standard_D11_v2, Standard_D12_v2, Standard_D13_v2, Standard_D14_v2, Standard_G1, Standard_G2, Standard_G3, Standard_G4, Standard_G5, Standard_D1_v2, Standard_DS2, Standard_DS3, Standard_DS4, Standard_DS11, Standard_DS12, Standard_DS13, Standard_DS14, Standard_DS1_v2, Standard_DS2_v2, Standard_DS3_v2, Standard_DS4_v2, Standard_DS5_v2, Standard_DS11_v2, Standard_DS12_v2, Standard_DS13_v2, Standard_DS14_v2, Standard_GS1, Standard_GS2, Standard_GS3, Standard_GS4, Standard_GS5"
  default     = "Standard_F32s_v2"
}

variable "os_storage_account_tier" {
  description = "Storage account Tier to use for operating system disks. Possible values include Standard and Premium."
  default     = "Standard"
}

variable "data_storage_account_tier" {
  description = "Storage account Tier to use for data disks, ie. local storage for containers. Possible values include Standard and Premium."
  default     = "Premium"
}

variable "storage_account_replication_type" {
  description = "This is the storage account Tier that you will need based on the vm size that you choose (value constraints)"
  default     = "LRS"
}

variable "enableMetrics" {
  description = "Enable OpenShift Metrics: true or false"
  default     = "false"
}

variable "enableLogging" {
  description = "Enable OpenShift Logging: true or false"
  default     = "false"
}

variable "enableCockpit" {
  description = "Enable Cockpit: true or false"
  default     = "false"
}

variable "enableAzure" {
  description = "Enable Azure as Cloud Provider - true or false"
  default     = "false"
}

variable "enableCRS" {
  description = "Enable Container Ready Storage - true or false"
  default     = "false"
}

variable "storageKind" {
  description = "Use Managed or Unmanaged Disks - managed or unmanaged"
  default     = "managed"
}

variable "os_image_map" {
  description = "os image map"
  type        = "map"

  default = {
    centos_publisher = "Openlogic"
    centos_offer     = "CentOS"
    centos_sku       = "7.3"
    centos_version   = "latest"
    rhel_publisher   = "RedHat"
    rhel_offer       = "RHEL"
    rhel_sku         = "7.3"
    rhel_version     = "latest"
  }
}

variable "os_disk_size" {
  description = "os disk size"
  default     = 50
}

variable "data_disk_size" {
  description = "Size of data disk to attach to nodes for Docker volume - valid sizes are 128 GB, 512 GB and 1023 GB"
  default     = 128
}

variable "gluster_disk_size" {
  description = "Size of data disk to attach to gluster nodes for gluster disks - valid sizes are 128 GB, 512 GB and 1023 GB"
  default     = 1023
}

variable "gluster_disk_count" {
  description = "Number of gluster disks to attach to gluster nodes for gluster disks. Allowed values: 4-max number for VM size"
  default     = 4
}

variable "master_instance_count" {
  description = "Number of OpenShift masternodes to deploy. 1 is non HA and 3 is for HA."
  default     = 1
}

variable "infra_instance_count" {
  description = "Number of OpenShift infra nodes to deploy. 1 is non HA.  Choose 2 or 3 for HA."
  default     = 1
}

variable "node_instance_count" {
  description = "Number of OpenShift nodes to deploy. Allowed values: 1-30"
  default     = 1
}

variable "crsapp_instance_count" {
  description = "Number of Gluster app nodes to deploy. Allowed values: 1-30"
  default     = 1
}

variable "crsreg_instance_count" {
  description = "Number of Gluster registry nodes to deploy. Allowed values: 1-30"
  default     = 1
}

variable "admin_username" {
  description = "Admin username for both OS login and OpenShift login"
  default     = "ocpadmin"
}

variable "openshift_password" {
  description = "Password for OpenShift login"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH Public Key"
}

variable "connection_private_ssh_key_path" {
  description = "Path to the private ssh key used to connect to machines within the OpenShift cluster."
}

variable "aad_client_id" {
  description = "Azure Active Directory Client ID also known as Application ID for Service Principal"
}

variable "aad_client_secret" {
  description = "Azure Active Directory Client Secret for Service Principal"
}

variable "default_sub_domain_type" {
  description = "This will either be 'nipio' (if you don't have your own domain) or 'custom' if you have your own domain that you would like to use for routing"
  default     = "nipio"
}

variable "default_sub_domain" {
  description = "The wildcard DNS name you would like to use for routing if you selected 'custom' above. If you selected 'nipio' above, then this field will be ignored"
  default     = "contoso.com"
}
