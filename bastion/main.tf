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

# Use existing ocp master state outputs
#data "terraform_remote_state" "ocpmaster" {
#  backend = "local"
#
#  config {
#    path = "./../${var.ocpmaster_module_name}/terraform.tfstate"
#  }
#}

data "terraform_remote_state" "ocpmaster" {
  backend = "azurerm"

  config {
    resource_group_name  = "${var.resource_group_name}"
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.project}-${var.ocpmaster_module_name}"
    key                  = "${var.key}"
  }
}

# Use existing ocp infra state outputs
#data "terraform_remote_state" "ocpinfra" {
#  backend = "local"
#
#  config {
#    path = "./../${var.ocpinfra_module_name}/terraform.tfstate"
#  }
#}

data "terraform_remote_state" "ocpinfra" {
  backend = "azurerm"

  config {
    resource_group_name  = "${var.resource_group_name}"
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.project}-${var.ocpinfra_module_name}"
    key                  = "${var.key}"
  }
}

# ******* NETWORK SECURITY GROUPS ***********

resource "azurerm_network_security_group" "bastion_nsg" {
  name                = "${var.project}-bastion-nsg"
  location            = "${data.terraform_remote_state.base.location}"
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"

  security_rule {
    name                       = "allow_SSH_in_all"
    description                = "Allow SSH in from all locations"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ******* STORAGE ACCOUNTS ***********

resource "azurerm_storage_account" "bastion_storage_account" {
  name                     = "${var.project}bastionsa"
  resource_group_name      = "${data.terraform_remote_state.base.resource_group_name}"
  location                 = "${data.terraform_remote_state.base.location}"
  account_tier             = "${var.os_storage_account_tier}"
  account_replication_type = "${var.storage_account_replication_type}"
}

# ******* IP ADDRESSES ***********

resource "random_id" "bastiondns" {
  byte_length = 4
}

resource "azurerm_public_ip" "bastion_pip" {
  name                         = "${var.project}bastion${random_id.bastiondns.hex}"
  resource_group_name          = "${data.terraform_remote_state.base.resource_group_name}"
  location                     = "${data.terraform_remote_state.base.location}"
  public_ip_address_allocation = "Static"
  domain_name_label            = "${var.project}bastion${random_id.bastiondns.hex}"
}

# ******* NETWORK INTERFACES ***********

resource "azurerm_network_interface" "bastion_nic" {
  name                      = "${var.project}-bastion-nic${count.index}"
  location                  = "${data.terraform_remote_state.base.location}"
  resource_group_name       = "${data.terraform_remote_state.base.resource_group_name}"
  network_security_group_id = "${azurerm_network_security_group.bastion_nsg.id}"

  ip_configuration {
    name                          = "bastionip"
    subnet_id                     = "${data.terraform_remote_state.base.master_subnet_id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.bastion_pip.id}"
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

# ******* Bastion Host *******

resource "azurerm_virtual_machine" "bastion" {
  name                             = "${var.project}-bastion"
  location                         = "${data.terraform_remote_state.base.location}"
  resource_group_name              = "${data.terraform_remote_state.base.resource_group_name}"
  network_interface_ids            = ["${azurerm_network_interface.bastion_nic.id}"]
  vm_size                          = "${var.bastion_vm_size}"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  tags {
    displayName = "${var.project}-bastion VM Creation"
    environment = "${var.project}-${var.environment}-${var.env_version}"
  }

  os_profile {
    computer_name  = "${var.project}-bastion"
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
    name              = "${var.project}-bastion-osdisk"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.os_disk_size}"
    create_option     = "FromImage"
    managed_disk_type = "${var.os_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-bastion-docker-pool"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.os_disk_size}"
    create_option     = "Empty"
    lun               = 0
    managed_disk_type = "${var.data_storage_account_tier}_${var.storage_account_replication_type}"
  }

  lifecycle {
    ignore_changes = ["storage_os_disk", "os_profile", "storage_data_disk"]
  }
}

resource "azurerm_virtual_machine_extension" "bastionPrep" {
  name                 = "bastionPrep"
  location             = "${data.terraform_remote_state.base.location}"
  resource_group_name  = "${data.terraform_remote_state.base.resource_group_name}"
  virtual_machine_name = "${azurerm_virtual_machine.bastion.name}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
        {
            "fileUris": [
            "https://raw.githubusercontent.com/heatmiser/openshift-container-platform/release-3.9/scripts/bastionPrep_cri-o.sh",
            "https://raw.githubusercontent.com/heatmiser/openshift-container-platform/release-3.9/scripts/deployOpenShift_cri-o.sh"
            ],
            "timestamp": 1523950636
        }
       SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
           {
               "commandToExecute": "bash bastionPrep_cri-o.sh \"${var.rhn_user}\" \"${var.rhn_passwd}\" \"${var.rhn_poolid}\" \"${trimspace(file(var.connection_private_ssh_key_path))}\" \"${var.admin_username}\" && sleep 15 && tmux new-session -d -s deployOpenShift \"./deployOpenShift_cri-o.sh \"${var.admin_username}\" \"${var.openshift_password}\" \"${var.project}-master\" \"${data.terraform_remote_state.ocpmaster.openshift_master_pip_fqdn}\" \"${data.terraform_remote_state.ocpmaster.openshift_master_pip_ipaddr}\" \"${var.project}-infra\" \"${var.project}-node\" \"${var.node_instance_count}\" \"${var.infra_instance_count}\" \"${var.master_instance_count}\" \"${data.terraform_remote_state.ocpinfra.openshift_infra_load_balancer_ipaddr}.nip.io\" \"${data.terraform_remote_state.ocpinfra.registry_storage_account_name}\" \"${data.terraform_remote_state.ocpinfra.registry_storage_account_primary_access_key}\" \"${var.enableMetrics}\" \"${var.enableLogging}\" \"${var.tenant_id}\" \"${var.subscription_id}\" \"${var.aad_client_id}\" \"${var.aad_client_secret}\" \"${data.terraform_remote_state.base.resource_group_name}\" \"${data.terraform_remote_state.base.location}\" \"${var.enableCockpit}\"  \"${var.enableAzure}\" \"${var.storageKind}\" \"${var.enableCRS}\" \"${var.project}-crsapp\" \"${var.crsapp_instance_count}\" \"${var.project}-crsreg\" \"${var.crsreg_instance_count}\" \"${var.gluster_disk_count}\" 2>&1 | tee deployOpenShift.log\""
           }
       PROTECTED_SETTINGS

  tags {
    environment = "${var.project}-${var.environment}-${var.env_version}"
  }
}
