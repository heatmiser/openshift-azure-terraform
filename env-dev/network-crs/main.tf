module "network-crs" {
  source = "../../modules/network-crs"

  resource_group_name              = "${var.resource_group_name}"
  storage_account_name             = "${var.storage_account_name}"
  key                              = "${var.key}"
  container_name                   = "${var.container_name}"
  project                          = "${var.project}"
  environment                      = "${var.environment}"
  env_version                      = "${var.env_version}"
  resource_group_name              = "${var.resource_group_name}"
  location                         = "${var.location}"
  images_resource_group            = "${var.images_resource_group}"
  base_os_image                    = "${var.base_os_image}"
  ocp_cidr_block                   = "${var.ocp_cidr_block}"
  ocp_cidrsubnet_newbits           = "${var.ocp_cidrsubnet_newbits}"
  crs_cidr_block                   = "${var.crs_cidr_block}"
  crs_cidrsubnet_newbits           = "${var.crs_cidrsubnet_newbits}"
  network1_module_name             = "${var.network1_module_name}"
  network2_module_name             = "${var.network2_module_name}"
  ocpmaster_module_name            = "${var.ocpmaster_module_name}"
  ocpinfra_module_name             = "${var.ocpinfra_module_name}"
  ocpnode_module_name              = "${var.ocpnode_module_name}"
  ocpbastion_module_name           = "${var.ocpbastion_module_name}"
  ocpcrs_app_module_name           = "${var.ocpcrs_app_module_name}"
  ocpcrs_registry_module_name      = "${var.ocpcrs_registry_module_name}"
  ocpopenvpn_module_name           = "${var.ocpopenvpn_module_name}"
  ocpopenvpn_module_name           = "${var.ocpopenvpn_module_name}"
  singlequote                      = "'"
  subscription_id                  = "${var.subscription_id}"
  tenant_id                        = "${var.tenant_id}"
  openshift_script_path            = "${var.openshift_script_path}"
  os_image                         = ""
  bastion_vm_size                  = "${var.bastion_vm_size}"
  master_vm_size                   = "${var.master_vm_size}"
  infra_vm_size                    = "${var.infra_vm_size}"
  node_vm_size                     = "${var.node_vm_size}"
  gluster_vm_size                  = "${var.gluster_vm_size}"
  os_storage_account_tier          = "${var.os_storage_account_tier}"
  data_storage_account_tier        = "${var.data_storage_account_tier}"
  storage_account_replication_type = "${var.storage_account_replication_type}"
  enableMetrics                    = "${var.enableMetrics}"
  enableLogging                    = "${var.enableLogging}"
  enableCockpit                    = "${var.enableCockpit}"
  enableAzure                      = "${var.enableAzure}"
  enableCRS                        = "${var.enableCRS}"
  storageKind                      = "${var.storageKind}"
  master_instance_count            = "${var.master_instance_count}"
  infra_instance_count             = "${var.infra_instance_count}"
  node_instance_count              = "${var.infra_instance_count}"
  crsapp_instance_count            = "${var.crsapp_instance_count}"
  crsreg_instance_count            = "${var.crsreg_instance_count}"
  os_disk_size                     = "${var.os_disk_size}"
  data_disk_size                   = "${var.data_disk_size}"
  gluster_disk_size                = "${var.gluster_disk_size}"
  gluster_disk_count               = "${var.gluster_disk_count}"
  admin_username                   = "${var.admin_username}"
  openshift_password               = "${var.openshift_password}"
  ssh_public_key_path              = "${var.ssh_public_key_path}"
  connection_private_ssh_key_path  = "${var.connection_private_ssh_key_path}"
  aad_client_id                    = "${var.aad_client_id}"
  aad_client_secret                = "${var.aad_client_secret}"
  default_sub_domain_type          = "${var.default_sub_domain_type}"
  default_sub_domain               = "${var.default_sub_domain}"
  rhn_user                         = "${var.rhn_user}"
  rhn_passwd                       = "${var.rhn_passwd}"
  rhn_poolid                       = "${var.rhn_poolid}"
  ocp_storage_addon_poolid         = "${var.ocp_storage_addon_poolid}"
}
