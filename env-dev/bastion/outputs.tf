output "jumpbox_public_fqdn" {
    value = "${module.bastion.jumpbox_public_fqdn}"
}

output "openshift_master_ssh" {
  value = "ssh ${module.bastion.openshift_master_ssh}"
}

output "environment" {
    value = "${module.bastion.environment}"
}
