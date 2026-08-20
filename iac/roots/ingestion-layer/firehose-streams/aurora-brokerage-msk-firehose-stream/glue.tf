# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

module "aurora_brokerage_transactions_table" {

  source         = "../../../../templates/modules/glue-transactions-table"
  APP            = var.APP
  ENV            = var.ENV
  DATABASE_NAME  = local.AURORA_DATABASE_NAME
  TABLE_NAME     = var.AURORA_BROKERAGE_TABLE_NAME
  TABLE_TYPE     = "brokerage"
  S3_BUCKET_NAME = data.aws_s3_bucket.iceberg_datalake_bucket.id
}
