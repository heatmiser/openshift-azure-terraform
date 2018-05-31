# CRS backend network deployment

data "azurerm_resource_group" "ocp" {
  name = "${var.resource_group_name}"
}

# ******* VNETS / SUBNETS ***********

data "azurerm_virtual_network" "vnet" {
  name                 = "${var.project}-vnet"
  resource_group_name  = "${data.azurerm_resource_group.ocp.name}"
}

# ******* BACKEND crsapp SUBNET ***********

resource "azurerm_subnet" "crs_subnet" {
  name                 = "${var.project}-${var.network2_module_name}-subnet"
  virtual_network_name = "${data.azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${data.azurerm_resource_group.ocp.name}"
  address_prefix       = "${cidrsubnet(data.azurerm_virtual_network.vnet.address_spaces[1], var.crs_cidrsubnet_newbits, 0)}"
}
