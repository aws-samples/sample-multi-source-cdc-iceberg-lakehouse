# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "firehose_delivery_stream_name" {
  description = "Name of the Firehose delivery stream"
  value       = module.aurora_firehose_ingestion.firehose_delivery_stream_name
}

output "firehose_delivery_stream_arn" {
  description = "ARN of the Firehose delivery stream"
  value       = module.aurora_firehose_ingestion.firehose_delivery_stream_arn
}

output "firehose_role_arn" {
  description = "ARN of the IAM role used by Firehose"
  value       = module.aurora_firehose_ingestion.firehose_role_arn
}

output "glue_table_name" {
  description = "Name of the Glue table"
  value       = module.aurora_brokerage_transactions_table.table_name
}

output "lambda_function_name" {
  description = "Name of the Lambda transformer function"
  value       = module.firehose_lambda_transformer.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda transformer function"
  value       = module.firehose_lambda_transformer.lambda_function_arn
}
