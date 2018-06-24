variable "project" {
  description = "Project name, also used as Cluster Prefix used to configure domain name label and hostnames for all nodes - master, infra and node. Between 1 and 20 characters"
}

variable "environment" {}
variable "env_version" {}
variable "resource_group_name" {}
variable "location" {}
variable "storage_account_name" {}
variable "network1_module_name" {}
variable "network2_module_name" {}
variable "ocpmaster_module_name" {}
variable "ocpinfra_module_name" {}
variable "ocpnode_module_name" {}
variable "ocpcrs_app_module_name" {}
variable "ocpcrs_registry_module_name" {}
variable "ocpbastion_module_name" {}
variable "ocpopenvpn_module_name" {}
variable "gluster_disk_count" {}
