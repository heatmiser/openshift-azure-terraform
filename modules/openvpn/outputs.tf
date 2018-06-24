output "openvpn_public_fqdn" {
    value = "${azurerm_public_ip.openvpn_pip.fqdn}"
}

output "openshift_openvpn_ssh" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.openvpn_pip.fqdn}"
}

output "environment" {
    value = "${var.project}-${var.environment}-${var.env_version}"
}
