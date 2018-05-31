# Use data resources for existing infrastructure

data "azurerm_resource_group" "ocp" {
  name = "${var.resource_group_name}"
}

# ******* VNETS / SUBNETS ***********

data "azurerm_virtual_network" "vnet" {
  name                = "${var.project}-vnet"
  resource_group_name = "${data.azurerm_resource_group.ocp.name}"
}

# ******* FRONTEND NODE SUBNET ***********
data "azurerm_subnet" "node_subnet" {
  name                 = "${var.project}-nodesubnet"
  virtual_network_name = "${data.azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${data.azurerm_resource_group.ocp.name}"
}

# ******* BACKEND CRS SUBNET ***********
data "azurerm_subnet" "crs_subnet" {
  name                 = "${var.project}-${var.network2_module_name}-subnet"
  virtual_network_name = "${data.azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${data.azurerm_resource_group.ocp.name}"
}

# ******* NETWORK SECURITY GROUPS ***********

resource "azurerm_network_security_group" "crsapp_fe_nsg" {
  name                = "${var.project}-${var.ocpcrs_app_module_name}-fe-nsg"
  location            = "${data.azurerm_resource_group.ocp.location}"
  resource_group_name = "${data.azurerm_resource_group.ocp.name}"
}

resource "azurerm_network_security_group" "crsapp_be_nsg" {
  name                = "${var.project}-${var.ocpcrs_app_module_name}-be-nsg"
  location            = "${data.azurerm_resource_group.ocp.location}"
  resource_group_name = "${data.azurerm_resource_group.ocp.name}"
}

# ******* AVAILABILITY SETS ***********

resource "azurerm_availability_set" "crsapp" {
  name                = "${var.ocpcrs_app_module_name}availabilityset"
  resource_group_name = "${data.azurerm_resource_group.ocp.name}"
  location            = "${data.azurerm_resource_group.ocp.location}"
  managed             = "true"
}

# ******* NETWORK INTERFACES ***********

resource "azurerm_network_interface" "crsapp_fe_nic" {
  name                      = "${var.project}-${var.ocpcrs_app_module_name}-fe-nic${format("%02d", count.index)}"
  location                  = "${data.azurerm_resource_group.ocp.location}"
  resource_group_name       = "${data.azurerm_resource_group.ocp.name}"
  network_security_group_id = "${azurerm_network_security_group.crsapp_fe_nsg.id}"
  count                     = "${var.crsapp_instance_count}"

  ip_configuration {
    name                          = "${var.ocpcrs_app_module_name}-fe-ip${format("%02d", count.index)}"
    subnet_id                     = "${data.azurerm_subnet.node_subnet.id}"
    private_ip_address_allocation = "Dynamic"
    primary                       = "true"
  }
}

resource "azurerm_network_interface" "crsapp_be_nic" {
  name                      = "${var.project}-${var.ocpcrs_app_module_name}-be-nic${format("%02d", count.index)}"
  location                  = "${data.azurerm_resource_group.ocp.location}"
  resource_group_name       = "${data.azurerm_resource_group.ocp.name}"
  network_security_group_id = "${azurerm_network_security_group.crsapp_be_nsg.id}"
  count                     = "${var.crsapp_instance_count}"

  ip_configuration {
    name                          = "${var.ocpcrs_app_module_name}-be-ip${format("%02d", count.index)}"
    subnet_id                     = "${data.azurerm_subnet.crs_subnet.id}"
    private_ip_address_allocation = "Dynamic"
    primary                       = "false"
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

# ******* crsapp VMs *******

resource "azurerm_virtual_machine" "crsapp" {
  name                             = "${var.project}-${var.ocpcrs_app_module_name}-${format("%02d", count.index)}"
  location                         = "${data.azurerm_resource_group.ocp.location}"
  resource_group_name              = "${data.azurerm_resource_group.ocp.name}"
  availability_set_id              = "${azurerm_availability_set.crsapp.id}"
  network_interface_ids            = ["${element(azurerm_network_interface.crsapp_fe_nic.*.id, format("%02d", count.index))}", "${element(azurerm_network_interface.crsapp_be_nic.*.id, format("%02d", count.index))}"]
  primary_network_interface_id     = "${element(azurerm_network_interface.crsapp_fe_nic.*.id, format("%02d", count.index))}"
  vm_size                          = "${var.gluster_vm_size}"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true
  count                            = "${var.crsapp_instance_count}"

  tags {
    displayName = "${var.project}-${var.ocpcrs_app_module_name} VM Creation"
    environment = "${var.project}-${var.environment}-${var.env_version}"
  }

  os_profile {
    computer_name  = "${var.project}-${var.ocpcrs_app_module_name}-${format("%02d", count.index)}"
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
    name              = "${var.project}-${var.ocpcrs_app_module_name}-${format("%02d", count.index)}-osdisk"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.os_disk_size}"
    create_option     = "FromImage"
    managed_disk_type = "${var.os_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-${var.ocpcrs_app_module_name}-${format("%02d", count.index)}-docker-pool"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.data_disk_size}"
    create_option     = "Empty"
    lun               = 0
    managed_disk_type = "${var.data_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-${var.ocpcrs_app_module_name}-${format("%02d", count.index)}-p30-disk00"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.gluster_disk_size}"
    create_option     = "Empty"
    lun               = 1
    managed_disk_type = "${var.data_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-${var.ocpcrs_app_module_name}-${format("%02d", count.index)}-p30-disk01"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.gluster_disk_size}"
    create_option     = "Empty"
    lun               = 2
    managed_disk_type = "${var.data_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-${var.ocpcrs_app_module_name}-${format("%02d", count.index)}-p30-disk02"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.gluster_disk_size}"
    create_option     = "Empty"
    lun               = 3
    managed_disk_type = "${var.data_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-${var.ocpcrs_app_module_name}-${format("%02d", count.index)}-p30-disk03"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.gluster_disk_size}"
    create_option     = "Empty"
    lun               = 4
    managed_disk_type = "${var.data_storage_account_tier}_${var.storage_account_replication_type}"
  }

  lifecycle {
    ignore_changes = ["storage_os_disk", "os_profile", "storage_data_disk"]
  }
}

resource "azurerm_virtual_machine_extension" "crsappPrep" {
  name                 = "${var.ocpcrs_app_module_name}Prep-${count.index}"
  location             = "${data.azurerm_resource_group.ocp.location}"
  resource_group_name  = "${data.azurerm_resource_group.ocp.name}"
  virtual_machine_name = "${element(azurerm_virtual_machine.crsapp.*.name, format("%02d", count.index))}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  count                = "${var.crsapp_instance_count}"
  depends_on           = ["azurerm_virtual_machine.crsapp"]

  settings = <<SETTINGS
        {
            "fileUris": ["https://raw.githubusercontent.com/heatmiser/openshift-container-platform/release-3.9/scripts/glusterPrep_cri-o.sh"],
            "timestamp": 1523950635
        }
       SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
           {
              "commandToExecute": "bash glusterPrep_cri-o.sh \"${var.rhn_user}\" \"${var.rhn_passwd}\" \"${var.rhn_poolid}\""
           }
       PROTECTED_SETTINGS

  tags {
    environment = "${var.project}-${var.environment}-${var.env_version}"
  }
}
