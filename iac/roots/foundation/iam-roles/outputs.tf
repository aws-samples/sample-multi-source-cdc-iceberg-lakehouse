# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Glue Role Outputs
output "glue_role_arn" {
  description = "ARN of the Glue service role"
  value       = aws_iam_role.aws_iam_glue_role.arn
}

output "glue_role_name" {
  description = "Name of the Glue service role"
  value       = aws_iam_role.aws_iam_glue_role.name
}

# Lake Formation Role Outputs
output "lakeformation_service_role_arn" {
  description = "ARN of the Lake Formation service role"
  value       = aws_iam_role.lakeformation_service_role.arn
}

output "lakeformation_service_role_name" {
  description = "Name of the Lake Formation service role"
  value       = aws_iam_role.lakeformation_service_role.name
}

# CockroachDB Role Outputs
output "cockroachdb_role_arn" {
  description = "ARN of the CockroachDB IAM role"
  value       = aws_iam_role.cockroachdb_role.arn
}

output "cockroachdb_role_name" {
  description = "Name of the CockroachDB IAM role"
  value       = aws_iam_role.cockroachdb_role.name
}

output "cockroachdb_instance_profile_arn" {
  description = "ARN of the CockroachDB instance profile"
  value       = aws_iam_instance_profile.cockroachdb_profile.arn
}

output "cockroachdb_instance_profile_name" {
  description = "Name of the CockroachDB instance profile"
  value       = aws_iam_instance_profile.cockroachdb_profile.name
}
