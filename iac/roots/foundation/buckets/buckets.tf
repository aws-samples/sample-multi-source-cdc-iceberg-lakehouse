# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_kms_key" "s3_primary_key" {

  provider = aws.primary
  key_id   = "alias/${var.S3_PRIMARY_KMS_KEY_ALIAS}"
}

module "athena_output_bucket" {

  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary = aws.primary
  }

  RESOURCE_PREFIX            = "${var.APP}-${var.ENV}-athena-output"
  BUCKET_NAME_PRIMARY_REGION = "primary"
  PRIMARY_CMK_ARN            = data.aws_kms_key.s3_primary_key.arn
  APP                        = var.APP
  ENV                        = var.ENV
  USAGE                      = "athena"
}

module "iceberg_datalake_bucket" {

  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary = aws.primary
  }

  RESOURCE_PREFIX            = "${var.APP}-${var.ENV}-iceberg-datalake"
  BUCKET_NAME_PRIMARY_REGION = "primary"
  PRIMARY_CMK_ARN            = data.aws_kms_key.s3_primary_key.arn
  APP                        = var.APP
  ENV                        = var.ENV
  USAGE                      = "iceberg"
}

module "assets_bucket" {
  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary = aws.primary
  }

  RESOURCE_PREFIX            = "${var.APP}-${var.ENV}-assets"
  BUCKET_NAME_PRIMARY_REGION = "primary"
  PRIMARY_CMK_ARN            = data.aws_kms_key.s3_primary_key.arn
  APP                        = var.APP
  ENV                        = var.ENV
  USAGE                      = "project-assets"
}
module "msk_connect_plugins" {
  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary = aws.primary
  }

  RESOURCE_PREFIX            = "${var.APP}-${var.ENV}-msk-connect-plugins"
  BUCKET_NAME_PRIMARY_REGION = "primary"
  PRIMARY_CMK_ARN            = data.aws_kms_key.s3_primary_key.arn
  APP                        = var.APP
  ENV                        = var.ENV
  USAGE                      = "msk-connect-plugins"
}
