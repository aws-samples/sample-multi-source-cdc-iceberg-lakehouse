# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

module "msk_firehose_ingestion" {

  source = "../../../../templates/modules/msk-firehose-ingestion"

  APP                  = var.APP
  ENV                  = var.ENV
  FIREHOSE_STREAM_NAME = var.FIREHOSE_STREAM_NAME
  REGION               = var.REGION
  S3_BUCKET_ARN        = data.aws_s3_bucket.iceberg_datalake_bucket.arn
  S3_KMS_ARN           = local.S3_KMS_ARN

  MSK_CLUSTER_ARN  = local.MSK_CLUSTER_ARN
  MSK_CLUSTER_NAME = local.MSK_CLUSTER_NAME
  TOPIC_NAME       = local.TOPIC_NAME

  GLUE_DATABASE_NAME = local.MSK_DATABASE_NAME
  GLUE_TABLE_NAME    = var.MSK_BROKERAGE_TABLE_NAME
  TABLE_TYPE         = "brokerage"

  # Disable Lambda transformation for MSK data
  ENABLE_LAMBDA_TRANSFORMATION = false

  # Ensure Glue table is created before Firehose stream
  depends_on = [
    module.msk_brokerage_transactions_table
  ]
}

# S3 Tables Firehose stream — writes to S3 Tables via Glue federated catalog
module "msk_firehose_ingestion_s3tables" {

  source = "../../../../templates/modules/msk-firehose-ingestion"

  APP                  = var.APP
  ENV                  = var.ENV
  FIREHOSE_STREAM_NAME = "${var.FIREHOSE_STREAM_NAME}-s3tables"
  REGION               = var.REGION
  S3_BUCKET_ARN        = data.aws_s3_bucket.iceberg_datalake_bucket.arn
  S3_KMS_ARN           = local.S3_KMS_ARN
  CATALOG_ARN          = local.S3_TABLES_CATALOG_ARN

  MSK_CLUSTER_ARN  = local.MSK_CLUSTER_ARN
  MSK_CLUSTER_NAME = local.MSK_CLUSTER_NAME
  TOPIC_NAME       = local.TOPIC_NAME

  GLUE_DATABASE_NAME = local.MSK_DATABASE_NAME
  GLUE_TABLE_NAME    = "brk"
  TABLE_TYPE         = "brokerage"

  ENABLE_S3_TABLES_OUTPUT = true
  S3_TABLES_BUCKET_ARN    = local.S3_TABLES_BUCKET_ARN

  ENABLE_LAMBDA_TRANSFORMATION = false
}
