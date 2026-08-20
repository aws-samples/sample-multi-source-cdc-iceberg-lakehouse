# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "connector_arn" {
  description = "ARN of the MSK Connect Debezium connector"
  value       = aws_mskconnect_connector.debezium.arn
}

output "connector_name" {
  description = "Name of the MSK Connect Debezium connector"
  value       = aws_mskconnect_connector.debezium.name
}

output "custom_plugin_arn" {
  description = "ARN of the Debezium custom plugin"
  value       = aws_mskconnect_custom_plugin.debezium.arn
}

output "worker_configuration_arn" {
  description = "ARN of the worker configuration"
  value       = aws_mskconnect_worker_configuration.debezium.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for the connector"
  value       = aws_cloudwatch_log_group.connector_logs.name
}
