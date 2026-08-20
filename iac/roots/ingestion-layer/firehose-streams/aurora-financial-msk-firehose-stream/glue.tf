# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

module "aurora_financial_transactions_table" {

  source         = "../../../../templates/modules/glue-transactions-table"
  APP            = var.APP
  ENV            = var.ENV
  DATABASE_NAME  = local.AURORA_DATABASE_NAME
  TABLE_NAME     = var.AURORA_FINANCIAL_TABLE_NAME
  TABLE_TYPE     = "financial"
  S3_BUCKET_NAME = data.aws_s3_bucket.iceberg_datalake_bucket.id
}
