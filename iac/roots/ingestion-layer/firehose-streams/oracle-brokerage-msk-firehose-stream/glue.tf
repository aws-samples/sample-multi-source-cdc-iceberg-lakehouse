# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

module "oracle_brokerage_transactions_table" {

  source         = "../../../../templates/modules/glue-transactions-table"
  APP            = var.APP
  ENV            = var.ENV
  DATABASE_NAME  = local.ORACLE_DATABASE_NAME
  TABLE_NAME     = var.ORACLE_BROKERAGE_TABLE_NAME
  TABLE_TYPE     = "brokerage"
  S3_BUCKET_NAME = data.aws_s3_bucket.iceberg_datalake_bucket.id
}
