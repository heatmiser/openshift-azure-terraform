output "node_os_storage_account_name" {
  value = "${azurerm_storage_account.nodeos_storage_account.name}"
}

output "node_data_storage_account_name" {
  value = "${azurerm_storage_account.nodedata_storage_account.name}"
}
