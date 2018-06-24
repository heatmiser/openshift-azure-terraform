output "vnet_name" {
  value = "${azurerm_virtual_network.vnet.name}"
}

output "vnet_address_space" {
  value = "${azurerm_virtual_network.vnet.address_space}"
}

output "master_subnet_id" {
  value = "${azurerm_subnet.master_subnet.id}"
}

output "node_subnet_id" {
  value = "${azurerm_subnet.node_subnet.id}"
}

output "master_subnet_address_range" {
  value = "${azurerm_subnet.master_subnet.address_prefix}"
}

output "node_subnet_address_range" {
  value = "${azurerm_subnet.node_subnet.address_prefix}"
}
