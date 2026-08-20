# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "iceberg_datalake_bucket_id" {
  description = "ID of the Iceberg datalake bucket"
  value       = module.iceberg_datalake_bucket.primary_bucket_id
}

output "iceberg_datalake_bucket_arn" {
  description = "ARN of the Iceberg datalake bucket"
  value       = module.iceberg_datalake_bucket.primary_bucket_arn
}
