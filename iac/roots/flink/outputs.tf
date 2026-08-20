# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "flink_application_names" {
  description = "Map of source key → Managed Flink application name"
  value       = { for k, app in aws_kinesisanalyticsv2_application.flink : k => app.name }
}

output "flink_application_arns" {
  description = "Map of source key → Managed Flink application ARN"
  value       = { for k, app in aws_kinesisanalyticsv2_application.flink : k => app.arn }
}

output "flink_role_arn" {
  description = "IAM role ARN used as the Flink service execution role"
  value       = aws_iam_role.flink_role.arn
}

output "flink_security_group_id" {
  description = "Security group ID attached to Flink applications"
  value       = aws_security_group.flink.id
}

output "flink_log_group_name" {
  description = "CloudWatch log group name for all Flink applications"
  value       = aws_cloudwatch_log_group.flink.name
}
