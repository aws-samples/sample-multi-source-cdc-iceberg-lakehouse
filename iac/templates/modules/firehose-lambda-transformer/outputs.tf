# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "lambda_function_arn" {
  description = "ARN of the Lambda transformation function"
  value       = module.dms_transformer_lambda.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda transformation function"
  value       = module.dms_transformer_lambda.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.dms_transformer_lambda.role_arn
}

output "lambda_log_group_name" {
  description = "Name of the Lambda CloudWatch log group"
  value       = module.dms_transformer_lambda.log_group_name
}
