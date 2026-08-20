# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

output "primary_bucket_arn" {

  description = "The ARN of the primary bucket"
  value       = aws_s3_bucket.primary.arn
}

output "primary_bucket_id" {

  description = "The ID of the primary bucket"
  value       = aws_s3_bucket.primary.id
}

output "primary_bucket_regional_domain_name" {

  description = "The primary bucket regional domain name"
  value       = aws_s3_bucket.primary.bucket_regional_domain_name
}

output "primary_bucket_name" {

  description = "name of the bucket in te primary region"
  value       = aws_s3_bucket.primary.bucket
}
