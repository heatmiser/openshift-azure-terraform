output "openshift_infra_load_balancer_fqdn" {
  value = "${module.infra.openshift_infra_load_balancer_fqdn}"
}

output "openshift_infra_load_balancer_ipaddr" {
  value = "${module.infra.openshift_infra_load_balancer_ipaddr}"
}

output "infra_storage_account_name" {
  value = "${module.infra.infra_storage_account_name}"
}

output "registry_storage_account_name" {
  value = "${module.infra.registry_storage_account_name}"
}

output "registry_storage_account_primary_access_key" {
  value = "${module.infra.registry_storage_account_primary_access_key}"
}
