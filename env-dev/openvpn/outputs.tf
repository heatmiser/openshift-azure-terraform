output "openvpn_public_fqdn" {
  value = "${module.openvpn.openvpn_public_fqdn}"
}

output "openshift_openvpn_ssh" {
  value = "${module.openvpn.openshift_openvpn_ssh}"
}

output "environment" {
  value = "${module.openvpn.environment}"
}
