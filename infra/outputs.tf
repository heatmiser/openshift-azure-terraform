output "openshift_infra_load_balancer_fqdn" {
  value = "${azurerm_public_ip.infra_lb_pip.fqdn}"
}

output "openshift_infra_load_balancer_ipaddr" {
  value = "${azurerm_public_ip.infra_lb_pip.ip_address}"
}

output "infra_storage_account_name" {
  value = "${azurerm_storage_account.infra_storage_account.name}"
}

output "registry_storage_account_name" {
  value = "${azurerm_storage_account.registry_storage_account.name}"
}

output "registry_storage_account_primary_access_key" {
  value = "${azurerm_storage_account.registry_storage_account.primary_access_key}"
}
