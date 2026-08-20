# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "firehose_delivery_stream_name" {
  description = "Name of the Kinesis Data Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.delivery_stream.name
}

output "firehose_delivery_stream_arn" {
  description = "ARN of the Kinesis Data Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.delivery_stream.arn
}

output "firehose_role_arn" {
  description = "ARN of the IAM role used by Firehose"
  value       = aws_iam_role.firehose_role.arn
}

output "firehose_role_name" {
  description = "Name of the IAM role used by Firehose"
  value       = aws_iam_role.firehose_role.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Firehose"
  value       = aws_cloudwatch_log_group.firehose_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for Firehose"
  value       = aws_cloudwatch_log_group.firehose_logs.arn
}

output "cloudwatch_log_stream_name" {
  description = "Name of the CloudWatch log stream for Firehose"
  value       = aws_cloudwatch_log_stream.firehose_log_stream.name
}

output "cloudwatch_log_stream_arn" {
  description = "ARN of the CloudWatch log stream for Firehose"
  value       = aws_cloudwatch_log_stream.firehose_log_stream.arn
}
