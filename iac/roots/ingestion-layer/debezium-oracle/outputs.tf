# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "connector_arn" {
  description = "ARN of the Debezium Oracle source connector"
  value       = module.debezium_oracle.connector_arn
}

output "connector_name" {
  description = "Name of the Debezium Oracle source connector"
  value       = module.debezium_oracle.connector_name
}

output "custom_plugin_arn" {
  description = "ARN of the Debezium Oracle custom plugin"
  value       = module.debezium_oracle.custom_plugin_arn
}

output "worker_configuration_arn" {
  description = "ARN of the Debezium Oracle worker configuration"
  value       = module.debezium_oracle.worker_configuration_arn
}

output "log_group_name" {
  description = "CloudWatch log group name for the Debezium Oracle connector"
  value       = module.debezium_oracle.log_group_name
}
