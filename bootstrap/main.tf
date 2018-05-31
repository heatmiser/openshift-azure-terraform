# Base deployment

data "azurerm_resource_group" "ocp" {
  name = "${var.resource_group_name}"
}

# ******* AZURE STORAGE CONTAINERS FOR TERRAFORM STATE ***********

resource "azurerm_storage_container" "network" {
  name                  = "${var.project}-${var.network1_module_name}"
  resource_group_name   = "${data.azurerm_resource_group.ocp.name}"
  storage_account_name  = "${var.storage_account_name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "network-crs" {
  name                  = "${var.project}-${var.network2_module_name}"
  resource_group_name   = "${data.azurerm_resource_group.ocp.name}"
  storage_account_name  = "${var.storage_account_name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "masters" {
  name                  = "${var.project}-${var.ocpmaster_module_name}"
  resource_group_name   = "${data.azurerm_resource_group.ocp.name}"
  storage_account_name  = "${var.storage_account_name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "infra" {
  name                  = "${var.project}-${var.ocpinfra_module_name}"
  resource_group_name   = "${data.azurerm_resource_group.ocp.name}"
  storage_account_name  = "${var.storage_account_name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "nodes" {
  name                  = "${var.project}-${var.ocpnodes_module_name}"
  resource_group_name   = "${data.azurerm_resource_group.ocp.name}"
  storage_account_name  = "${var.storage_account_name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "bastion" {
  name                  = "${var.project}-${var.ocpbastion_module_name}"
  resource_group_name   = "${data.azurerm_resource_group.ocp.name}"
  storage_account_name  = "${var.storage_account_name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "crsapp" {
  name                  = "${var.project}-${var.ocpcrs_app_module_name}"
  resource_group_name   = "${data.azurerm_resource_group.ocp.name}"
  storage_account_name  = "${var.storage_account_name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "crsregistry" {
  name                  = "${var.project}-${var.ocpcrs_registry_module_name}"
  resource_group_name   = "${data.azurerm_resource_group.ocp.name}"
  storage_account_name  = "${var.storage_account_name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "openvpn" {
  name                  = "${var.project}-${var.ocpopenvpn_module_name}"
  resource_group_name   = "${data.azurerm_resource_group.ocp.name}"
  storage_account_name  = "${var.storage_account_name}"
  container_access_type = "private"
}

data "external" "timestamp" {
  program = ["bash", "${path.module}/scripts/create_timestamp_json.sh"]
}

# dynamically create crsapp main.tf from several sub-templates
data "template_file" "crsapp-1" {
  template = "${file("${path.module}/templates/crsapp-1.tmpl")}"
}

data "template_file" "crsapp-datadisk" {
  count    = "${var.gluster_disk_count}"
  template = "${file("${path.module}/templates/crsapp-datadisk.tmpl")}"

  vars {
    DISKNUM = "${format("%02d", count.index)}"
    LUNNUM  = "${count.index + 1}"
  }
}

data "template_file" "crsapp-2" {
  template = "${file("${path.module}/templates/crsapp-2.tmpl")}"

  vars {
    TIMESTAMP = "${data.external.timestamp.result.timestamp}"
  }

  depends_on = ["data.external.timestamp"]
}

resource "local_file" "crsapp-main" {
  content  = "${data.template_file.crsapp-1.rendered} ${join("\n",data.template_file.crsapp-datadisk.*.rendered)} ${data.template_file.crsapp-2.rendered}"
  filename = "${path.module}/output/crsapp-main.tf"
}

# dynamically create crsregistry main.tf from several sub-templates
data "template_file" "crsregistry-1" {
  template = "${file("${path.module}/templates/crsregistry-1.tmpl")}"
}

data "template_file" "crsregistry-datadisk" {
  count    = "${var.gluster_disk_count}"
  template = "${file("${path.module}/templates/crsregistry-datadisk.tmpl")}"

  vars {
    DISKNUM = "${format("%02d", count.index)}"
    LUNNUM  = "${count.index + 1}"
  }
}

data "template_file" "crsregistry-2" {
  template = "${file("${path.module}/templates/crsregistry-2.tmpl")}"

  vars {
    TIMESTAMP = "${data.external.timestamp.result.timestamp}"
  }

  depends_on = ["data.external.timestamp"]
}

resource "local_file" "crsregistry-main" {
  content  = "${data.template_file.crsregistry-1.rendered} ${join("\n",data.template_file.crsregistry-datadisk.*.rendered)} ${data.template_file.crsregistry-2.rendered}"
  filename = "${path.module}/output/crsregistry-main.tf"
}
