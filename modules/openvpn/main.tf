# Use existing bootstrap state

data "terraform_remote_state" "bootstrap" {
  backend = "azurerm"

  config {
    resource_group_name  = "${var.resource_group_name}"
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.project}-bootstrap"
    key                  = "${var.key}"
  }
}

data "terraform_remote_state" "network1" {
  backend = "azurerm"

  config {
    resource_group_name  = "${var.resource_group_name}"
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.project}-${var.network1_module_name}"
    key                  = "${var.key}"
  }
}

locals {
  subnet_list = ["${data.terraform_remote_state.network1.master_subnet_address_range}", "${data.terraform_remote_state.network1.node_subnet_address_range}"]
}

resource "random_id" "completion_tag" {
  byte_length = 12
}

# ******* NETWORK SECURITY GROUPS ***********

resource "azurerm_network_security_group" "openvpn_nsg" {
  name                = "${var.project}-openvpn-nsg"
  location            = "${data.terraform_remote_state.bootstrap.location}"
  resource_group_name = "${data.terraform_remote_state.bootstrap.resource_group_name}"

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

  security_rule {
    name                       = "allow_OpenVPNudp_in_SNXGVL"
    description                = "Allow OpenVPN in from SYNNEX Greenville"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "1194"
    source_address_prefix      = "24.159.132.2/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_OpenVPNudp_in_SAVHOME"
    description                = "Allow OpenVPN in from Savage Residence"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "1194"
    source_address_prefix      = "97.81.192.18/32"
    destination_address_prefix = "*"
  }
}

# ******* STORAGE ACCOUNTS ***********

resource "azurerm_storage_account" "openvpn_storage_account" {
  name                     = "${var.project}openvpnsa"
  resource_group_name      = "${data.terraform_remote_state.bootstrap.resource_group_name}"
  location                 = "${data.terraform_remote_state.bootstrap.location}"
  account_tier             = "${var.os_storage_account_tier}"
  account_replication_type = "${var.storage_account_replication_type}"
}

# ******* IP ADDRESSES ***********

resource "azurerm_public_ip" "openvpn_pip" {
  name                         = "${var.project}${var.environment}openvpnpip"
  resource_group_name          = "${data.terraform_remote_state.bootstrap.resource_group_name}"
  location                     = "${data.terraform_remote_state.bootstrap.location}"
  public_ip_address_allocation = "Static"
  domain_name_label            = "${var.project}openvpn${data.terraform_remote_state.bootstrap.random_id}"
}

# ******* NETWORK INTERFACES ***********

resource "azurerm_network_interface" "openvpn_nic" {
  name                      = "${var.project}-${var.ocpopenvpn_module_name}-nic${count.index}"
  location                  = "${data.terraform_remote_state.bootstrap.location}"
  resource_group_name       = "${data.terraform_remote_state.bootstrap.resource_group_name}"
  network_security_group_id = "${azurerm_network_security_group.openvpn_nsg.id}"

  ip_configuration {
    name                          = "${var.project}-${var.ocpopenvpn_module_name}-ip"
    subnet_id                     = "${data.terraform_remote_state.network1.master_subnet_id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.openvpn_pip.id}"
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

data "template_file" "user-data-rsa" {
  count    = "${var.crypto_algo_elliptical == "rsa" ? 1 : 0}"
  template = "${file("${path.module}/user-data/openvpn-rsa.tmpl")}"

  vars {
    USERNAME_ORG         = "${var.rhn_user}"
    PASSWORD_ACT_KEY     = "${var.rhn_passwd}"
    RHN_POOL_ID          = "${var.rhn_poolid}"
    OPENVPN_PUB_DNS_NAME = "${azurerm_public_ip.openvpn_pip.fqdn}"
    OPENVPN_PUB_IP       = "${azurerm_public_ip.openvpn_pip.ip_address}"
    OPENVPN_LAN_RANGE    = "${join(",", local.subnet_list)}"
    RANDOM_STRING        = "${random_id.completion_tag.hex}"
  }
}

# ******* openvpn Host *******

resource "azurerm_virtual_machine" "openvpn-rsa" {
  name                             = "${var.project}-${var.ocpopenvpn_module_name}"
  location                         = "${data.terraform_remote_state.bootstrap.location}"
  resource_group_name              = "${data.terraform_remote_state.bootstrap.resource_group_name}"
  network_interface_ids            = ["${azurerm_network_interface.openvpn_nic.id}"]
  vm_size                          = "${var.openvpn_vm_size}"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true
  count                            = "${var.crypto_algo_elliptical == "rsa" ? 1 : 0}"

  tags {
    displayName = "${var.project}-${var.ocpopenvpn_module_name} VM"
    configlabel = "${data.terraform_remote_state.bootstrap.configlabel}"
  }

  os_profile {
    computer_name  = "${var.project}-${var.ocpopenvpn_module_name}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.openshift_password}"
    custom_data    = "${data.template_file.user-data-rsa.rendered}"
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
    name              = "${var.project}-${var.ocpopenvpn_module_name}-osdisk"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.os_disk_size}"
    create_option     = "FromImage"
    managed_disk_type = "${var.os_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-${var.ocpopenvpn_module_name}-container-pool"
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

resource "azurerm_virtual_machine_extension" "openvpnPrep-rsa" {
  name                 = "openvpnPrep-rsa"
  location             = "${data.terraform_remote_state.bootstrap.location}"
  resource_group_name  = "${data.terraform_remote_state.bootstrap.resource_group_name}"
  virtual_machine_name = "${azurerm_virtual_machine.openvpn-rsa.name}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  count                = "${var.crypto_algo_elliptical == "rsa" ? 1 : 0}"

  settings = <<SETTINGS
        {
            "fileUris": [
            "https://raw.githubusercontent.com/heatmiser/terraform-openshift-origin/master/scripts/placehold2.sh",
            "https://raw.githubusercontent.com/heatmiser/terraform-openshift-origin/master/scripts/trapit"
            ],
	          "timestamp": 1523950635
        }
       SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
           {
               "commandToExecute": "bash placehold2.sh && sleep 5 && bash trapit -e \"${random_id.completion_tag.hex}\" -f /var/log/cloud-tools.out -t \"echo $(date -R) - Azure VM extension scripts complete\""
           }
       PROTECTED_SETTINGS

  tags {
    configlabel = "${data.terraform_remote_state.bootstrap.configlabel}"
  }
}

data "template_file" "user-data-ec" {
  count    = "${var.crypto_algo_elliptical == "ec" ? 1 : 0}"
  template = "${file("${path.module}/user-data/openvpn-ecdh.tmpl")}"

  vars {
    USERNAME_ORG              = "${var.rhn_user}"
    PASSWORD_ACT_KEY          = "${var.rhn_passwd}"
    RHN_POOL_ID               = "${var.rhn_poolid}"
    OPENVPN_PUB_DNS_NAME      = "${azurerm_public_ip.openvpn_pip.fqdn}"
    OPENVPN_PUB_IP            = "${azurerm_public_ip.openvpn_pip.ip_address}"
    OPENVPN_LAN_RANGE         = "${join(",", local.subnet_list)}"
    RANDOM_STRING             = "${random_id.completion_tag.hex}"
    OPENVPN_CLIENT_CERT_NAME  = "${var.openvpn_client_cert_name}"
    OPENVPN_CLIENT_CERT_STATE = "${var.openvpn_client_cert_state}"
    OPENVPN_CLIENT_CERT_CITY  = "${var.openvpn_client_cert_city}"
    OPENVPN_CLIENT_CERT_ORG   = "${var.openvpn_client_cert_org}"
    OPENVPN_CLIENT_CERT_EMAIL = "${var.openvpn_client_cert_email}"
    OPENVPN_CLIENT_CERT_OU    = "${var.openvpn_client_cert_ou}"
  }
}

# ******* openvpn Host *******

resource "azurerm_virtual_machine" "openvpn-ec" {
  name                             = "${var.project}-${var.ocpopenvpn_module_name}"
  location                         = "${data.terraform_remote_state.bootstrap.location}"
  resource_group_name              = "${data.terraform_remote_state.bootstrap.resource_group_name}"
  network_interface_ids            = ["${azurerm_network_interface.openvpn_nic.id}"]
  vm_size                          = "${var.openvpn_vm_size}"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true
  count                            = "${var.crypto_algo_elliptical == "ec" ? 1 : 0}"

  tags {
    displayName = "${var.project}-${var.ocpopenvpn_module_name} VM"
    configlabel = "${data.terraform_remote_state.bootstrap.configlabel}"
  }

  os_profile {
    computer_name  = "${var.project}-${var.ocpopenvpn_module_name}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.openshift_password}"
    custom_data    = "${data.template_file.user-data-ec.rendered}"
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
    name              = "${var.project}-${var.ocpopenvpn_module_name}-osdisk"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.os_disk_size}"
    create_option     = "FromImage"
    managed_disk_type = "${var.os_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-${var.ocpopenvpn_module_name}-container-pool"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.os_disk_size}"
    create_option     = "Empty"
    lun               = 0
    managed_disk_type = "${var.data_storage_account_tier}_${var.storage_account_replication_type}"
  }
}

resource "azurerm_virtual_machine_extension" "openvpnPrep-ec" {
  name                 = "openvpnPrep-ec"
  location             = "${data.terraform_remote_state.bootstrap.location}"
  resource_group_name  = "${data.terraform_remote_state.bootstrap.resource_group_name}"
  virtual_machine_name = "${azurerm_virtual_machine.openvpn-ec.name}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  count                = "${var.crypto_algo_elliptical == "ec" ? 1 : 0}"

  settings = <<SETTINGS
        {
            "fileUris": [
            "https://raw.githubusercontent.com/heatmiser/terraform-openshift-origin/master/scripts/placehold2.sh",
            "https://raw.githubusercontent.com/heatmiser/terraform-openshift-origin/master/scripts/trapit"
            ],
	          "timestamp": 1523950635
        }
       SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
           {
               "commandToExecute": "bash placehold2.sh && sleep 5 && bash trapit -e \"${random_id.completion_tag.hex}\" -f /var/log/cloud-tools.out -t \"echo $(date -R) - Azure VM extension scripts complete\""
           }
       PROTECTED_SETTINGS

  tags {
    configlabel = "${data.terraform_remote_state.bootstrap.configlabel}"
  }
}
