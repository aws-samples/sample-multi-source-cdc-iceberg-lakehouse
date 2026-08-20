# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "oracle_transactions_database_name" {
  description = "Name of the Oracle transactions Glue database"
  value       = aws_glue_catalog_database.oracle_transactions_database.name
}

output "aurora_transactions_database_name" {
  description = "Name of the Aurora transactions Glue database"
  value       = aws_glue_catalog_database.aurora_transactions_database.name
}

output "cockroach_transactions_database_name" {
  description = "Name of the CockroachDB transactions Glue database"
  value       = aws_glue_catalog_database.cockroach_transactions_database.name
}

output "msk_transactions_database_name" {
  description = "Name of the MSK transactions Glue database"
  value       = aws_glue_catalog_database.msk_transactions_database.name
}

output "oracle_transactions_database_arn" {
  description = "ARN of the Oracle transactions Glue database"
  value       = aws_glue_catalog_database.oracle_transactions_database.arn
}

output "aurora_transactions_database_arn" {
  description = "ARN of the Aurora transactions Glue database"
  value       = aws_glue_catalog_database.aurora_transactions_database.arn
}

output "cockroach_transactions_database_arn" {
  description = "ARN of the CockroachDB transactions Glue database"
  value       = aws_glue_catalog_database.cockroach_transactions_database.arn
}

output "msk_transactions_database_arn" {
  description = "ARN of the MSK transactions Glue database"
  value       = aws_glue_catalog_database.msk_transactions_database.arn
}
