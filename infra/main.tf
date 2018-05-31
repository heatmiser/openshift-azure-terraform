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

resource "azurerm_network_security_group" "infra_nsg" {
  name                = "${var.project}-infra-nsg"
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

  security_rule {
    name                       = "allow_HTTP_in_all"
    description                = "Allow HTTP connections from all locations"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ******* STORAGE ACCOUNTS & STORAGE CONTAINERS ***********

resource "azurerm_storage_account" "infra_storage_account" {
  name                     = "${var.project}infrasa"
  resource_group_name      = "${data.terraform_remote_state.base.resource_group_name}"
  location                 = "${data.terraform_remote_state.base.location}"
  account_tier             = "${var.os_storage_account_tier}"
  account_replication_type = "${var.storage_account_replication_type}"
}

resource "azurerm_storage_account" "registry_storage_account" {
  name                     = "${var.project}regsa"
  resource_group_name      = "${data.terraform_remote_state.base.resource_group_name}"
  location                 = "${data.terraform_remote_state.base.location}"
  account_tier             = "${var.os_storage_account_tier}"
  account_replication_type = "${var.storage_account_replication_type}"
}

resource "azurerm_storage_container" "registry" {
  name                  = "registry"
  resource_group_name   = "${data.terraform_remote_state.base.resource_group_name}"
  storage_account_name  = "${azurerm_storage_account.registry_storage_account.name}"
  container_access_type = "private"
  depends_on            = ["azurerm_storage_account.registry_storage_account"]
}

# ******* AVAILABILITY SETS ***********

resource "azurerm_availability_set" "infra" {
  name                = "infraavailabilityset"
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  location            = "${data.terraform_remote_state.base.location}"
  managed             = "true"
}

# ******* IP ADDRESSES ***********

resource "random_id" "infradns" {
  byte_length = 4
}

resource "azurerm_public_ip" "infra_lb_pip" {
  name                         = "${var.project}infra${random_id.infradns.hex}"
  resource_group_name          = "${data.terraform_remote_state.base.resource_group_name}"
  location                     = "${data.terraform_remote_state.base.location}"
  public_ip_address_allocation = "Static"
  domain_name_label            = "${var.project}infra${random_id.infradns.hex}"
}

# ******* INFRA LOAD BALANCER ***********

resource "azurerm_lb" "infra_lb" {
  name                = "infraloadbalancer"
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  location            = "${data.terraform_remote_state.base.location}"
  depends_on          = ["azurerm_public_ip.infra_lb_pip"]

  frontend_ip_configuration {
    name                 = "infraLbFrontEndConfig"
    public_ip_address_id = "${azurerm_public_ip.infra_lb_pip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "infra_lb" {
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  name                = "infraLbBackEndPool"
  loadbalancer_id     = "${azurerm_lb.infra_lb.id}"
  depends_on          = ["azurerm_lb.infra_lb"]
}

resource "azurerm_lb_probe" "infra_lb_http_probe" {
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.infra_lb.id}"
  name                = "httpProbe"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
  protocol            = "Tcp"
  depends_on          = ["azurerm_lb.infra_lb"]
}

resource "azurerm_lb_probe" "infra_lb_https_probe" {
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.infra_lb.id}"
  name                = "httpsProbe"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 2
  protocol            = "Tcp"
}

resource "azurerm_lb_probe" "infra_lb_cockpit_probe" {
  resource_group_name = "${data.terraform_remote_state.base.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.infra_lb.id}"
  name                = "cockpitProbe"
  port                = 9090
  interval_in_seconds = 5
  number_of_probes    = 2
  protocol            = "Tcp"
}

resource "azurerm_lb_rule" "infra_lb_http" {
  resource_group_name            = "${data.terraform_remote_state.base.resource_group_name}"
  loadbalancer_id                = "${azurerm_lb.infra_lb.id}"
  name                           = "OpenShiftRouterHTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "infraLbFrontEndConfig"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.infra_lb.id}"
  probe_id                       = "${azurerm_lb_probe.infra_lb_http_probe.id}"
  depends_on                     = ["azurerm_lb_probe.infra_lb_http_probe", "azurerm_lb.infra_lb", "azurerm_lb_backend_address_pool.infra_lb"]
}

resource "azurerm_lb_rule" "infra_lb_https" {
  resource_group_name            = "${data.terraform_remote_state.base.resource_group_name}"
  loadbalancer_id                = "${azurerm_lb.infra_lb.id}"
  name                           = "OpenShiftRouterHTTPS"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "infraLbFrontEndConfig"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.infra_lb.id}"
  probe_id                       = "${azurerm_lb_probe.infra_lb_https_probe.id}"
  depends_on                     = ["azurerm_lb_probe.infra_lb_https_probe", "azurerm_lb_backend_address_pool.infra_lb"]
}

resource "azurerm_lb_rule" "infra_lb_cockpit" {
  resource_group_name            = "${data.terraform_remote_state.base.resource_group_name}"
  loadbalancer_id                = "${azurerm_lb.infra_lb.id}"
  name                           = "OpenShiftRouterCockpit"
  protocol                       = "Tcp"
  frontend_port                  = 9090
  backend_port                   = 9090
  frontend_ip_configuration_name = "infraLbFrontEndConfig"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.infra_lb.id}"
  probe_id                       = "${azurerm_lb_probe.infra_lb_cockpit_probe.id}"
  depends_on                     = ["azurerm_lb_probe.infra_lb_cockpit_probe", "azurerm_lb_backend_address_pool.infra_lb"]
}

# ******* NETWORK INTERFACES ***********

resource "azurerm_network_interface" "infra_nic" {
  name                      = "${var.project}-infra-nic${format("%02d", count.index)}"
  location                  = "${data.terraform_remote_state.base.location}"
  resource_group_name       = "${data.terraform_remote_state.base.resource_group_name}"
  network_security_group_id = "${azurerm_network_security_group.infra_nsg.id}"
  count                     = "${var.infra_instance_count}"

  ip_configuration {
    name                                    = "infra-ip${format("%02d", count.index)}"
    subnet_id                               = "${data.terraform_remote_state.base.master_subnet_id}"
    private_ip_address_allocation           = "Dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.infra_lb.id}"]
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

# ******* Infra VMs *******

resource "azurerm_virtual_machine" "infra" {
  name                             = "${var.project}-infra-${format("%02d", count.index)}"
  location                         = "${data.terraform_remote_state.base.location}"
  resource_group_name              = "${data.terraform_remote_state.base.resource_group_name}"
  availability_set_id              = "${azurerm_availability_set.infra.id}"
  network_interface_ids            = ["${element(azurerm_network_interface.infra_nic.*.id, format("%02d", count.index))}"]
  vm_size                          = "${var.infra_vm_size}"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true
  count                            = "${var.infra_instance_count}"

  tags {
    displayName = "${var.project}-infra VM Creation"
    environment = "${var.project}-${var.environment}-${var.env_version}"
  }

  os_profile {
    computer_name  = "${var.project}-infra-${format("%02d", count.index)}"
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
    name              = "${var.project}-infra-${format("%02d", count.index)}-osdisk"
    caching           = "ReadWrite"
    disk_size_gb      = "${var.os_disk_size}"
    create_option     = "FromImage"
    managed_disk_type = "${var.os_storage_account_tier}_${var.storage_account_replication_type}"
  }

  storage_data_disk {
    name              = "${var.project}-infra-${format("%02d", count.index)}-docker-pool"
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

resource "azurerm_virtual_machine_extension" "infraPrep" {
  name                 = "infraPrep-${count.index}"
  location             = "${data.terraform_remote_state.base.location}"
  resource_group_name  = "${data.terraform_remote_state.base.resource_group_name}"
  virtual_machine_name = "${element(azurerm_virtual_machine.infra.*.name, format("%02d", count.index))}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  count                = "${var.infra_instance_count}"
  depends_on           = ["azurerm_virtual_machine.infra"]

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
