# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.athena_workgroup.name
}

output "athena_workgroup_arn" {
  description = "ARN of the Athena workgroup"
  value       = aws_athena_workgroup.athena_workgroup.arn
}

output "athena_output_bucket" {
  description = "S3 bucket URI for Athena query results"
  value       = var.ATHENA_OUTPUT_BUCKET
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for Athena encryption"
  value       = data.aws_kms_key.athena_kms_key.arn
}
