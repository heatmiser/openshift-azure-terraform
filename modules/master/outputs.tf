output "openshift_console_url" {
  value = "https://${azurerm_public_ip.openshift_master_pip.fqdn}/console"
}

output "openshift_master_pip_fqdn" {
  value = "${azurerm_public_ip.openshift_master_pip.fqdn}"
}

output "openshift_master_pip_ipaddr" {
  value = "${azurerm_public_ip.openshift_master_pip.ip_address}"
}

output "openshift_master_nsg_name" {
  value = "${azurerm_network_security_group.master_nsg.name}"
}
