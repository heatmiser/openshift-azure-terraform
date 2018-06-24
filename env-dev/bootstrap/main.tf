module "bootstrap" {
  source = "../../modules/bootstrap"

  resource_group_name  = "${var.resource_group_name}"
  storage_account_name = "${var.storage_account_name}"

  #key                         = "${var.key}"
  #container_name              = "${var.container_name}"
  project = "${var.project}"

  environment          = "${var.environment}"
  env_version          = "${var.env_version}"
  location             = "${var.location}"
  network1_module_name = "${var.network1_module_name}"

  network2_module_name        = "${var.network2_module_name}"
  ocpmaster_module_name       = "${var.ocpmaster_module_name}"
  ocpinfra_module_name        = "${var.ocpinfra_module_name}"
  ocpnode_module_name         = "${var.ocpnode_module_name}"
  ocpbastion_module_name      = "${var.ocpbastion_module_name}"
  ocpcrs_app_module_name      = "${var.ocpcrs_app_module_name}"
  ocpcrs_registry_module_name = "${var.ocpcrs_registry_module_name}"
  ocpopenvpn_module_name      = "${var.ocpopenvpn_module_name}"
  ocpopenvpn_module_name      = "${var.ocpopenvpn_module_name}"
  gluster_disk_count          = "${var.gluster_disk_count}"
}
