# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "table_name" {
  value       = aws_glue_catalog_table.transactions_table.name
  description = "The name of the transactions Glue table"
}

output "table_arn" {
  value       = aws_glue_catalog_table.transactions_table.arn
  description = "The ARN of the transactions Glue table"
}

output "table_type" {
  value       = var.TABLE_TYPE
  description = "The type of table created (financial or brokerage)"
}
