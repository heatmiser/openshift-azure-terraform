data "terraform_remote_state" "base" {
  backend = "azurerm"

  config {
    resource_group_name  = "${var.resource_group_name}"
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.project}-${var.network1_module_name}"
    key                  = "${var.key}"
  }
}

data "terraform_remote_state" "ocpmaster" {
  backend = "azurerm"

  config {
    resource_group_name  = "${var.resource_group_name}"
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.project}-${var.ocpmaster_module_name}"
    key                  = "${var.key}"
  }
}

data "terraform_remote_state" "ocpinfra" {
  backend = "azurerm"

  config {
    resource_group_name  = "${var.resource_group_name}"
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.project}-${var.ocpinfra_module_name}"
    key                  = "${var.key}"
  }
}

resource "local_file" "ansible_inventory_log" {
  content  = ""
  filename = "${path.module}/ansible_inventory.log"

  provisioner "local-exec" {
    command = "bash deployOpenShift_cri-o.sh \"${var.admin_username}\" \"${var.openshift_password}\" \"${var.project}-master\" \"${data.terraform_remote_state.ocpmaster.openshift_master_pip_fqdn}\" \"${data.terraform_remote_state.ocpmaster.openshift_master_pip_ipaddr}\" \"${var.project}-infra\" \"${var.project}-node\" \"${var.node_instance_count}\" \"${var.infra_instance_count}\" \"${var.master_instance_count}\" \"${data.terraform_remote_state.ocpinfra.openshift_infra_load_balancer_ipaddr}.nip.io\" \"${data.terraform_remote_state.ocpinfra.registry_storage_account_name}\" \"${data.terraform_remote_state.ocpinfra.registry_storage_account_primary_access_key}\" \"${var.enableMetrics}\" \"${var.enableLogging}\" \"${var.tenant_id}\" \"${var.subscription_id}\" \"${var.aad_client_id}\" \"${var.aad_client_secret}\" \"${data.terraform_remote_state.base.resource_group_name}\" \"${data.terraform_remote_state.base.location}\" \"${var.enableCockpit}\"  \"${var.enableAzure}\" \"${var.storageKind}\" \"${var.enableCRS}\" \"${var.project}-${var.ocpcrs_app_module_name}\" \"${var.crsapp_instance_count}\" \"${var.project}-${var.ocpcrs_registry_module_name}\" \"${var.crsreg_instance_count}\" \"${var.gluster_disk_count}\" > \"${local_file.ansible_inventory_log.filename}\""
  }
}

data "external" "timestamp" {
  program = ["bash", "${path.module}/scripts/create_timestamp_json.sh"]
}

data "template_file" "crsapp-1" {
  template = "${file("${path.module}/templates/crsapp-1.tmpl")}"
}

data "template_file" "crsapp-datadisk" {
  count = "${var.gluster_disk_count}"

  // count    = 4
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
