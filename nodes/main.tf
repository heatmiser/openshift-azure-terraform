# Use existing base state outputs
#data "terraform_remote_state" "base" {
#  backend = "local"
#
#  config {
#    path = "./../${var.network1_module_name}/terraform.tfstate"
#  }
#}

data "terraform_remote_state" "base" {
  backend = "azurerm"

  config {
    resource_group_name  = "${var.resource_group_name}"
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.project}-${var.network1_module_name}"
    key                  = "${var.key}"
  }
}

# ******* NETWORK SECURITY GROUPS ***********

resource "azurerm_network_security_group" "node_nsg" {
  name                = "${var.project}-node-nsg"
  location            = "${data.terraform_remote_state.base.location}"
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
}

# ******* STORAGE ACCOUNTS ***********

resource "azurerm_storage_account" "nodeos_storage_account" {
  name                     = "${var.project}nodeossa"
  resource_group_name      = "${data.terraform_remote_state.base.resource_group_name}"
  location                 = "${data.terraform_remote_state.base.location}"
  account_tier             = "${var.os_storage_account_tier}"
  account_replication_type = "${var.storage_account_replication_type}"
}

resource "azurerm_storage_account" "nodedata_storage_account" {
  name                     = "${var.project}nodedatasa"
  resource_group_name      = "${data.terraform_remote_state.base.resource_group_name}"
  location                 = "${data.terraform_remote_state.base.location}"
  account_tier             = "${var.data_storage_account_tier}"
  account_replication_type = "${var.storage_account_replication_type}"
}

# ******* AVAILABILITY SETS ***********

resource "azurerm_availability_set" "node" {
  name                = "nodeavailabilityset"
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  location            = "${data.terraform_remote_state.base.location}"
  managed             = "true"
}

# ******* NETWORK INTERFACES ***********

resource "azurerm_network_interface" "node_nic" {
  name                      = "${var.project}-node-nic${format("%02d", count.index)}"
  location                  = "${data.terraform_remote_state.base.location}"
  resource_group_name       = "${data.terraform_remote_state.base.resource_group_name}"
  network_security_group_id = "${azurerm_network_security_group.node_nsg.id}"
  count                     = "${var.node_instance_count}"

  ip_configuration {
    name                          = "node-ip${format("%02d", count.index)}"
    subnet_id                     = "${data.terraform_remote_state.base.node_subnet_id}"
    private_ip_address_allocation = "Dynamic"
  }
}

# ******* OS Image reference ********
data "azurerm_resource_group" "imagesource" {
  name = "${var.images_resource_group}"
}

data "azurerm_image" "image" {
  name                = "${var.base_os_image}"
  resource_group_name = "${data.azurerm_resource_group.imagesource.name}"
}

# ******* Node VMs *******

resource "azurerm_virtual_machine" "node" {
  name                             = "${var.project}-node-${format("%02d", count.index)}"
  location                         = "${data.terraform_remote_state.base.location}"
  resource_group_name              = "${data.terraform_remote_state.base.resource_group_name}"
  availability_set_id              = "${azurerm_availability_set.node.id}"
  network_interface_ids            = ["${element(azurerm_network_interface.node_nic.*.id, format("%02d", count.index))}"]
  vm_size                          = "${var.node_vm_size}"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true
  count                            = "${var.node_instance_count}"

  tags {
    displayName = "${var.project}-node VM Creation"
    environment = "${var.project}-${var.environment}-${var.env_version}"
  }

  os_profile {
    computer_name  = "${var.project}-node-${format("%02d", count.index)}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.openshift_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file(var.ssh_public_key_path)}"
    }
  }

  storage_image_reference {
    id = "${data.azurerm_image.image.id}"
  }

  storage_os_disk {
    name              = "${var.project}-node-${format("%02d", count.index)}-osdisk"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.os_disk_size}"
    create_option     = "FromImage"
    managed_disk_type = "${var.os_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-node-${format("%02d", count.index)}-docker-pool"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.data_disk_size}"
    create_option     = "Empty"
    lun               = 0
    managed_disk_type = "${var.data_storage_account_tier}_${var.storage_account_replication_type}"
  }

  lifecycle {
    ignore_changes = ["storage_os_disk", "os_profile", "storage_data_disk"]
  }
}

resource "azurerm_virtual_machine_extension" "nodePrep" {
  name                 = "nodePrep-${count.index}"
  location             = "${data.terraform_remote_state.base.location}"
  resource_group_name  = "${data.terraform_remote_state.base.resource_group_name}"
  virtual_machine_name = "${element(azurerm_virtual_machine.node.*.name, format("%02d", count.index))}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  count                = "${var.node_instance_count}"
  depends_on           = ["azurerm_virtual_machine.node", "azurerm_storage_account.nodedata_storage_account"]

  settings = <<SETTINGS
        {
            "fileUris": ["https://raw.githubusercontent.com/heatmiser/openshift-container-platform/release-3.9/scripts/nodePrep_cri-o.sh"],
            "timestamp": 1523950635
        }
       SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
           {
              "commandToExecute": "bash nodePrep_cri-o.sh \"${var.rhn_user}\" \"${var.rhn_passwd}\" \"${var.rhn_poolid}\" \"${var.ocp_storage_addon_poolid}\""
           }
       PROTECTED_SETTINGS

  tags {
    environment = "${var.project}-${var.environment}-${var.env_version}"
  }
}
