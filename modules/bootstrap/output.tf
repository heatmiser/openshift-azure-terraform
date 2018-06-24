output "resource_group_name" {
  value = "${var.resource_group_name}"
}

output "location" {
  value = "${var.location}"
}

output "random_id" {
  value = "${random_id.value01.hex}"
}

output "configlabel" {
  value = "${var.project}-${var.environment}-${var.env_version}"
}
