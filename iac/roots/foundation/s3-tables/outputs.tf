# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "table_bucket_arn" {
  description = "ARN of the S3 Tables table bucket"
  value       = aws_s3tables_table_bucket.iceberg_tables.arn
}

output "table_bucket_name" {
  description = "Name of the S3 Tables table bucket"
  value       = aws_s3tables_table_bucket.iceberg_tables.name
}

output "oracle_namespace" {
  description = "Oracle transactions namespace name"
  value       = aws_s3tables_namespace.oracle.namespace
}

output "aurora_namespace" {
  description = "Aurora transactions namespace name"
  value       = aws_s3tables_namespace.aurora.namespace
}

output "cockroach_namespace" {
  description = "CockroachDB transactions namespace name"
  value       = aws_s3tables_namespace.cockroach.namespace
}

output "msk_source_namespace" {
  description = "MSK source transactions namespace name"
  value       = aws_s3tables_namespace.msk_source.namespace
}
