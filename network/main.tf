# Base network deployment

data "azurerm_resource_group" "ocp" {
  name = "${var.resource_group_name}"
}

# ******* VNETS / SUBNETS ***********

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project}-vnet"
  location            = "${data.azurerm_resource_group.ocp.location}"
  resource_group_name = "${data.azurerm_resource_group.ocp.name}"
  address_space       = ["${var.ocp_cidr_block}", "${var.crs_cidr_block}"]
  depends_on          = ["data.azurerm_resource_group.ocp"]

  tags {
    environment = "${var.project}-${var.environment}-${var.env_version}"
  }
}

resource "azurerm_subnet" "master_subnet" {
  name                 = "${var.project}-mastersubnet"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${data.azurerm_resource_group.ocp.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.vnet.address_space[0], var.ocp_cidrsubnet_newbits, 0)}"
  depends_on           = ["azurerm_virtual_network.vnet"]
}

resource "azurerm_subnet" "node_subnet" {
  name                 = "${var.project}-nodesubnet"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${data.azurerm_resource_group.ocp.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.vnet.address_space[0], var.ocp_cidrsubnet_newbits, 1)}"
  depends_on           = ["azurerm_virtual_network.vnet"]
}
