# Use existing base state outputs
#data "terraform_remote_state" "base" {
#  backend = "local"
#
#  config {
#    path = "./../${var.network1_module_name}/.terraform/terraform.tfstate"
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

resource "azurerm_network_security_group" "master_nsg" {
  name                = "${var.project}-master-nsg"
  location            = "${data.terraform_remote_state.base.location}"
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"

  security_rule {
    name                       = "allow_HTTPS_all"
    description                = "Allow HTTPS connections from all locations"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ******* STORAGE ACCOUNTS ***********

resource "azurerm_storage_account" "master_storage_account" {
  name                     = "${var.project}mastersa"
  resource_group_name      = "${data.terraform_remote_state.base.resource_group_name}"
  location                 = "${data.terraform_remote_state.base.location}"
  account_tier             = "${var.os_storage_account_tier}"
  account_replication_type = "${var.storage_account_replication_type}"
}

resource "azurerm_storage_account" "persistent_volume_storage_account" {
  name                     = "${var.project}pvsa"
  resource_group_name      = "${data.terraform_remote_state.base.resource_group_name}"
  location                 = "${data.terraform_remote_state.base.location}"
  account_tier             = "${var.data_storage_account_tier}"
  account_replication_type = "${var.storage_account_replication_type}"
}

# ******* AVAILABILITY SETS ***********

resource "azurerm_availability_set" "master" {
  name                = "masteravailabilityset"
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  location            = "${data.terraform_remote_state.base.location}"
  managed             = "true"
}

# ******* IP ADDRESSES ***********

resource "random_id" "masterdns" {
  byte_length = 4
}

resource "azurerm_public_ip" "openshift_master_pip" {
  name                         = "${var.project}master${random_id.masterdns.hex}"
  resource_group_name          = "${data.terraform_remote_state.base.resource_group_name}"
  location                     = "${data.terraform_remote_state.base.location}"
  public_ip_address_allocation = "Static"
  domain_name_label            = "${var.project}master${random_id.masterdns.hex}"
}

# ******* MASTER LOAD BALANCER ***********

resource "azurerm_lb" "master_lb" {
  name                = "masterloadbalancer"
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  location            = "${data.terraform_remote_state.base.location}"
  depends_on          = ["azurerm_public_ip.openshift_master_pip"]

  frontend_ip_configuration {
    name                 = "masterLbFrontEndConfig"
    public_ip_address_id = "${azurerm_public_ip.openshift_master_pip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "master_lb" {
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  name                = "masterLbBackEndPool"
  loadbalancer_id     = "${azurerm_lb.master_lb.id}"
  depends_on          = ["azurerm_lb.master_lb"]
}

resource "azurerm_lb_probe" "master_lb" {
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.master_lb.id}"
  name                = "httpsProbe"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 2
  protocol            = "Tcp"
  depends_on          = ["azurerm_lb.master_lb"]
}

resource "azurerm_lb_probe" "cockpit_lb" {
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.master_lb.id}"
  name                = "CockpitProbe"
  port                = 9090
  interval_in_seconds = 5
  number_of_probes    = 2
  protocol            = "Tcp"
  depends_on          = ["azurerm_lb.master_lb"]
}

resource "azurerm_lb_rule" "master_lb" {
  resource_group_name            = "${data.terraform_remote_state.base.resource_group_name}"
  loadbalancer_id                = "${azurerm_lb.master_lb.id}"
  name                           = "OpenShiftAdminConsole"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "masterLbFrontEndConfig"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.master_lb.id}"
  load_distribution              = "SourceIP"
  idle_timeout_in_minutes        = 30
  probe_id                       = "${azurerm_lb_probe.master_lb.id}"
  enable_floating_ip             = false
  depends_on                     = ["azurerm_lb_probe.master_lb", "azurerm_lb.master_lb", "azurerm_lb_backend_address_pool.master_lb"]
}

resource "azurerm_lb_rule" "cockpit_lb" {
  resource_group_name            = "${data.terraform_remote_state.base.resource_group_name}"
  loadbalancer_id                = "${azurerm_lb.master_lb.id}"
  name                           = "CockpitConsole"
  protocol                       = "Tcp"
  frontend_port                  = 9090
  backend_port                   = 9090
  frontend_ip_configuration_name = "masterLbFrontEndConfig"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.master_lb.id}"
  load_distribution              = "SourceIP"
  idle_timeout_in_minutes        = 30
  probe_id                       = "${azurerm_lb_probe.cockpit_lb.id}"
  enable_floating_ip             = false
  depends_on                     = ["azurerm_lb_probe.cockpit_lb", "azurerm_lb.master_lb", "azurerm_lb_backend_address_pool.master_lb"]
}

#resource "azurerm_lb_nat_rule" "master_lb" {
#  resource_group_name            = "${data.terraform_remote_state.base.resource_group_name}"
#  loadbalancer_id                = "${azurerm_lb.master_lb.id}"
#  name                           = "${azurerm_lb.master_lb.name}-SSH-${count.index}"
#  protocol                       = "Tcp"
#  frontend_port                  = "${count.index + 2200}"
#  backend_port                   = 22
#  frontend_ip_configuration_name = "masterLbFrontEndConfig"
#  count                          = "${var.master_instance_count}"
#  depends_on                     = ["azurerm_lb.master_lb"]
#}

# ******* NETWORK INTERFACES ***********

resource "azurerm_network_interface" "master_nic" {
  name                      = "${var.project}-master-nic${format("%02d", count.index)}"
  location                  = "${data.terraform_remote_state.base.location}"
  resource_group_name       = "${data.terraform_remote_state.base.resource_group_name}"
  network_security_group_id = "${azurerm_network_security_group.master_nsg.id}"
  count                     = "${var.master_instance_count}"

  ip_configuration {
    name                                    = "master-ip${format("%02d", count.index)}"
    subnet_id                               = "${data.terraform_remote_state.base.master_subnet_id}"
    private_ip_address_allocation           = "Dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.master_lb.id}"]
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

# ******* Master VMs *******

resource "azurerm_virtual_machine" "master" {
  name                             = "${var.project}-master-${format("%02d", count.index)}"
  location                         = "${data.terraform_remote_state.base.location}"
  resource_group_name              = "${data.terraform_remote_state.base.resource_group_name}"
  availability_set_id              = "${azurerm_availability_set.master.id}"
  network_interface_ids            = ["${element(azurerm_network_interface.master_nic.*.id, format("%02d", count.index))}"]
  vm_size                          = "${var.master_vm_size}"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true
  count                            = "${var.master_instance_count}"

  tags {
    displayName = "${var.project}-master VM Creation"
    environment = "${var.project}-${var.environment}-${var.env_version}"
  }

  os_profile {
    computer_name  = "${var.project}-master-${format("%02d", count.index)}"
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
    name              = "${var.project}-master-${format("%02d", count.index)}-osdisk"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.os_disk_size}"
    create_option     = "FromImage"
    managed_disk_type = "${var.os_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-master-${format("%02d", count.index)}-docker-pool"
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

resource "azurerm_virtual_machine_extension" "masterPrep" {
  name                 = "masterPrep-${count.index}"
  location             = "${data.terraform_remote_state.base.location}"
  resource_group_name  = "${data.terraform_remote_state.base.resource_group_name}"
  virtual_machine_name = "${element(azurerm_virtual_machine.master.*.name, format("%02d", count.index))}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  count                = "${var.master_instance_count}"
  depends_on           = ["azurerm_virtual_machine.master"]

  settings = <<SETTINGS
        {
            "fileUris": ["https://raw.githubusercontent.com/heatmiser/openshift-container-platform/release-3.9/scripts/masterPrep_cri-o.sh"],
            "timestamp": 1523950635
        }
       SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
           {
              "commandToExecute": "bash masterPrep_cri-o.sh \"${var.rhn_user}\" \"${var.rhn_passwd}\" \"${var.rhn_poolid}\" \"${var.admin_username}\" \"${data.terraform_remote_state.base.location}\" \"${azurerm_storage_account.persistent_volume_storage_account.name}\" \"${var.ocp_storage_addon_poolid}\""
           }
       PROTECTED_SETTINGS

  tags {
    environment = "${var.project}-${var.environment}-${var.env_version}"
  }
}
