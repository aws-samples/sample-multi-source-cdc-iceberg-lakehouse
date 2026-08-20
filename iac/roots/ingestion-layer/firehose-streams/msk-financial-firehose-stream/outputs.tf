# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "firehose_delivery_stream_name" {
  description = "Name of the Firehose delivery stream"
  value       = module.msk_firehose_ingestion.firehose_delivery_stream_name
}

output "firehose_delivery_stream_arn" {
  description = "ARN of the Firehose delivery stream"
  value       = module.msk_firehose_ingestion.firehose_delivery_stream_arn
}

output "glue_table_name" {
  description = "Name of the Glue table"
  value       = module.msk_financial_transactions_table.table_name
}

