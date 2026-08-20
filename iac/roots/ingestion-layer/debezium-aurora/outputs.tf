# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "connector_arn" {
  description = "ARN of the Debezium Aurora source connector"
  value       = module.debezium_aurora.connector_arn
}

output "connector_name" {
  description = "Name of the Debezium Aurora source connector"
  value       = module.debezium_aurora.connector_name
}

output "custom_plugin_arn" {
  description = "ARN of the Debezium Aurora custom plugin"
  value       = module.debezium_aurora.custom_plugin_arn
}

output "worker_configuration_arn" {
  description = "ARN of the Debezium Aurora worker configuration"
  value       = module.debezium_aurora.worker_configuration_arn
}

output "log_group_name" {
  description = "CloudWatch log group name for the Debezium Aurora connector"
  value       = module.debezium_aurora.log_group_name
}
