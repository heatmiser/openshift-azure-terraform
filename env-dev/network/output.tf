output "vnet_name" {
  value = "${module.network.vnet_name}"
}

output "vnet_address_space" {
  value = "${module.network.vnet_address_space}"
}

output "master_subnet_id" {
  value = "${module.network.master_subnet_id}"
}

output "node_subnet_id" {
  value = "${module.network.node_subnet_id}"
}

output "master_subnet_address_range" {
  value = "${module.network.master_subnet_address_range}"
}

output "node_subnet_address_range" {
  value = "${module.network.node_subnet_address_range}"
}
