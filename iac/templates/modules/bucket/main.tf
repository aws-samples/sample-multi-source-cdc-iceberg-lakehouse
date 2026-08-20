# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {
  primary_bucket_name = "${var.RESOURCE_PREFIX}-${var.BUCKET_NAME_PRIMARY_REGION}"
}

# Create the primary bucket
resource "aws_s3_bucket" "primary" {
  #checkov:skip=CKV_AWS_18:S3 access logging disabled for this sample to reduce costs
  provider = aws.primary
  bucket   = local.primary_bucket_name

  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
  #checkov:skip=CKV2_AWS_61: "Ensure that an S3 bucket has a lifecycle configuration": "Skipping this for simplicity."
  #checkov:skip=CKV2_AWS_62: "Ensure S3 buckets should have event notifications enabled": "Skipping this as it will increase the cost of deploying the solution."
  #checkov:skip=CKV_AWS_144: Cross-region replication not required for this sample — single-region deployment, no DR requirement
}



# Create acl for the primary bucket

resource "aws_s3_bucket_ownership_controls" "primary_bucket_ownership_controls" {

  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }

  #checkov:skip=CKV2_AWS_65: "Ensure access control lists for S3 buckets are disabled": "Recommended BucketOwnerEnforced does not work, only BucketOwnerPreferred works."
}

resource "aws_s3_bucket_acl" "primary_acl" {

  provider = aws.primary

  bucket = aws_s3_bucket.primary.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.primary_bucket_ownership_controls]
}

# Block public access for primary bucket

resource "aws_s3_bucket_public_access_block" "public_access_block_primary" {

  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable primary bucket versioning

resource "aws_s3_bucket_versioning" "primary" {

  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable default encryption for primary bucket

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {

  provider = aws.primary

  bucket = aws_s3_bucket.primary.bucket

  rule {
    bucket_key_enabled = false
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.PRIMARY_CMK_ARN
      sse_algorithm     = "aws:kms"
    }
  }

  #checkov:skip=CKV2_AWS_67: "Ensure AWS S3 bucket encrypted with Customer Managed Key (CMK) has regular rotation": "All KMS Keys are configured with regular rotation."
}



