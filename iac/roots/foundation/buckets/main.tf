# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
terraform {
  required_version = ">= 1.8.0"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  tags = {
    Application = var.APP
    Environment = var.ENV
  }
}

// Store bucket information in SSM Parameter Store for other modules to use

resource "aws_ssm_parameter" "iceberg_datalake_bucket_name" {

  name   = "/${var.APP}/${var.ENV}/iceberg-datalake-bucket-name"
  type   = "SecureString"
  value  = module.iceberg_datalake_bucket.primary_bucket_id
  key_id = data.aws_kms_key.s3_primary_key.key_id

  tags = local.tags
}

resource "aws_ssm_parameter" "assets_bucket_name" {

  name   = "/${var.APP}/${var.ENV}/assets-bucket-name"
  type   = "SecureString"
  value  = module.assets_bucket.primary_bucket_id
  key_id = data.aws_kms_key.s3_primary_key.key_id

  tags = local.tags
}
resource "aws_ssm_parameter" "msk_connect_plugins_bucket_name" {

  name   = "/${var.APP}/${var.ENV}/msk-connect-plugins-bucket-name"
  type   = "SecureString"
  value  = module.msk_connect_plugins.primary_bucket_id
  key_id = data.aws_kms_key.s3_primary_key.key_id

  tags = local.tags
}

resource "aws_ssm_parameter" "msk_connect_plugins_bucket_arn" {

  name   = "/${var.APP}/${var.ENV}/msk-connect-plugins-bucket-arn"
  type   = "SecureString"
  value  = module.msk_connect_plugins.primary_bucket_arn
  key_id = data.aws_kms_key.s3_primary_key.key_id

  tags = local.tags
}
