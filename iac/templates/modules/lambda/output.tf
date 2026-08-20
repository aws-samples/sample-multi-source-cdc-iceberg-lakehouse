# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "role_arn" {
  description = "ARN of the IAM role used by the Lambda function"
  value       = var.create_role ? aws_iam_role.lambda_role[0].arn : var.role_arn
}

output "role_name" {
  description = "Name of the IAM role used by the Lambda function"
  value       = var.create_role ? aws_iam_role.lambda_role[0].name : null
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}
