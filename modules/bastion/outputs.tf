output "jumpbox_public_fqdn" {
    value = "${azurerm_public_ip.bastion_pip.fqdn}"
}

output "openshift_master_ssh" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.bastion_pip.fqdn}"
}

output "environment" {
    value = "${var.project}-${var.environment}-${var.env_version}"
}
