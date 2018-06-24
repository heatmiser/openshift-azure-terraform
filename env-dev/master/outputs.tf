output "openshift_console_url" {
  value = "${module.master.openshift_console_url}"
}

output "openshift_master_pip_fqdn" {
  value = "${module.master.openshift_master_pip_fqdn}"
}

output "openshift_master_pip_ipaddr" {
  value = "${module.master.openshift_master_pip_ipaddr}"
}

output "openshift_master_nsg_name" {
  value = "${module.master.openshift_master_nsg_name}"
}
