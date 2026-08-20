# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# ---------------------------------------------------------------------------
# Lake Formation permissions — S3 Tables federated catalog mode
# CatalogId format: <account_id>:s3tablescatalog/<bucket_name>
# ---------------------------------------------------------------------------

locals {
  # Extract bucket name from ARN: arn:aws:s3tables:<region>:<account>:bucket/<name>
  s3_tables_bucket_name   = var.S3_TABLES_BUCKET_ARN != "" ? element(split("/", var.S3_TABLES_BUCKET_ARN), length(split("/", var.S3_TABLES_BUCKET_ARN)) - 1) : ""
  s3_tables_lf_catalog_id = "${data.aws_caller_identity.current.account_id}:s3tablescatalog"
  s3_tables_lf_bucket_id  = "${data.aws_caller_identity.current.account_id}:s3tablescatalog/${local.s3_tables_bucket_name}"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# IAM assume role policy for Firehose
data "aws_iam_policy_document" "firehose_assume_role_policy" {

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

# CloudWatch Log Group for Firehose
resource "aws_cloudwatch_log_group" "firehose_logs" { // nosemgrep:
  #checkov:skip=CKV_AWS_338:Log retention configured per variable for cost optimization in this sample
  #checkov:skip=CKV_AWS_158:CloudWatch log encryption not required for this sample
  name              = "/aws/firehose/${var.APP}-${var.ENV}-${var.FIREHOSE_STREAM_NAME}"
  retention_in_days = var.LOG_RETENTION_DAYS

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "firehose-logs"
  }
}

# CloudWatch Log Stream for Firehose
resource "aws_cloudwatch_log_stream" "firehose_log_stream" {

  log_group_name = aws_cloudwatch_log_group.firehose_logs.name
  name           = "${var.APP}-${var.ENV}-${var.FIREHOSE_STREAM_NAME}-logs"
}

# IAM policy for Firehose
resource "aws_iam_policy" "firehose_policy" {

  name = "${var.APP}-${var.ENV}-${var.FIREHOSE_STREAM_NAME}-policy"
  path = "/"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : concat([
      {
        "Effect" : "Allow",
        // nosemgrep:
        "Action" : [
          "kafka:CreateVpcConnection"
        ],
        "Resource" : [var.MSK_CLUSTER_ARN]
      },
      {
        "Effect" : "Allow",
        // nosemgrep:
        "Action" : [
          "kafka:GetBootstrapBrokers",
          "kafka:DescribeCluster",
          "kafka:DescribeClusterV2",
          "kafka-cluster:Connect"
        ],
        "Resource" : [var.MSK_CLUSTER_ARN]
      },
      {
        "Effect" : "Allow",
        // nosemgrep:
        "Action" : [
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:DescribeTopicDynamicConfiguration",
          "kafka-cluster:ReadData"
        ],
        "Resource" : ["arn:aws:kafka:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:topic/${var.MSK_CLUSTER_NAME}/*"]
      },
      {
        "Effect" : "Allow",
        // nosemgrep:
        "Action" : [
          "kafka-cluster:DescribeGroup"
        ],
        "Resource" : ["arn:aws:kafka:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:group/${var.MSK_CLUSTER_NAME}/*"]
      },
      {
        "Effect" : "Allow",
        // nosemgrep:
        "Action" : [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:UpdateTable"
        ],
        "Resource" : [
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:database/${var.GLUE_DATABASE_NAME}",
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.GLUE_DATABASE_NAME}/${var.GLUE_TABLE_NAME}",
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "glue:GetSchemaVersion"
        ],
        "Resource" : ["*"]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject",
          "s3:DeleteObject",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ],
        "Resource" : [
          var.S3_BUCKET_ARN,
          "${var.S3_BUCKET_ARN}/*",
          var.S3_KMS_ARN
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:PutLogEvents"
        ],
        "Resource" : [
          aws_cloudwatch_log_stream.firehose_log_stream.arn
        ]
      }
      ], var.ENABLE_LAMBDA_TRANSFORMATION ? [
      {
        "Effect" : "Allow",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Resource" : [
          var.LAMBDA_TRANSFORMER_ARN
        ]
      }
      ] : [],
      var.ENABLE_S3_TABLES_OUTPUT ? [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3tables:GetTable",
            "s3tables:GetTableBucket",
            "s3tables:GetNamespace",
            "s3tables:ListTables",
            "s3tables:ListNamespaces",
            "s3tables:ListTableBuckets",
            "s3tables:PutTableData",
            "s3tables:GetTableData",
            "s3tables:GetTableMetadataLocation",
            "s3tables:UpdateTableMetadataLocation"
          ],
          "Resource" : [
            var.S3_TABLES_BUCKET_ARN,
            "${var.S3_TABLES_BUCKET_ARN}/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "glue:GetTable",
            "glue:GetDatabase",
            "glue:UpdateTable"
          ],
          "Resource" : [
            "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog/s3tablescatalog",
            "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog/s3tablescatalog/*",
            "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:database/s3tablescatalog/*",
            "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/s3tablescatalog/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : ["lakeformation:GetDataAccess"],
          "Resource" : ["*"]
        }
    ] : [])
  })

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "firehose-policy"
  }
}

# IAM role for Firehose
resource "aws_iam_role" "firehose_role" {

  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role_policy.json
  name               = "${var.APP}-${var.ENV}-${var.FIREHOSE_STREAM_NAME}-role"

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "firehose-role"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "firehose_policy_attachment" {

  policy_arn = aws_iam_policy.firehose_policy.arn
  role       = aws_iam_role.firehose_role.name
}

# Wait for IAM role propagation before creating Firehose stream.
# AWS IAM is eventually consistent — the role/policy may not be usable
# for ~10s after creation, causing "security token invalid" errors.
resource "time_sleep" "iam_propagation" {
  depends_on      = [aws_iam_role_policy_attachment.firehose_policy_attachment]
  create_duration = "30s"
}

# Kinesis Data Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "delivery_stream" {
  #checkov:skip=CKV_AWS_241:Customer-managed CMK not required for this sample — using AWS-owned encryption
  #checkov:skip=CKV_AWS_240:Stream delivers to Iceberg/S3 where data is encrypted at rest via the destination bucket KMS key; server-side encryption of the stream itself is not required for this sample
  destination = "iceberg"
  name        = "${var.APP}-${var.ENV}-${var.FIREHOSE_STREAM_NAME}"

  msk_source_configuration {
    msk_cluster_arn = var.MSK_CLUSTER_ARN
    authentication_configuration {
      connectivity = "PRIVATE"
      role_arn     = aws_iam_role.firehose_role.arn
    }
    topic_name = var.TOPIC_NAME
  }

  iceberg_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    catalog_arn        = var.CATALOG_ARN != "" ? var.CATALOG_ARN : "arn:aws:glue:${var.REGION}:${data.aws_caller_identity.current.account_id}:catalog"
    buffering_size     = var.BUFFERING_SIZE
    buffering_interval = var.BUFFERING_INTERVAL

    s3_configuration {
      role_arn            = aws_iam_role.firehose_role.arn
      bucket_arn          = var.S3_BUCKET_ARN
      prefix              = "${var.GLUE_TABLE_NAME}/"
      kms_key_arn         = var.S3_KMS_ARN
      error_output_prefix = "${var.GLUE_DATABASE_NAME}/${var.GLUE_TABLE_NAME}/errors/"
    }

    destination_table_configuration {
      database_name = var.GLUE_DATABASE_NAME
      table_name    = var.GLUE_TABLE_NAME
      unique_keys   = var.TABLE_TYPE == "financial" ? ["transaction_id"] : ["order_id"]
    }

    # Optional Lambda transformation for DMS data flattening
    dynamic "processing_configuration" {
      for_each = var.ENABLE_LAMBDA_TRANSFORMATION ? [1] : []
      content {
        enabled = true
        processors {
          type = "Lambda"
          parameters {
            parameter_name  = "LambdaArn"
            parameter_value = var.LAMBDA_TRANSFORMER_ARN
          }
          parameters {
            parameter_name  = "BufferSizeInMBs"
            parameter_value = var.BUFFERING_SIZE
          }
          parameters {
            parameter_name  = "BufferIntervalInSeconds"
            parameter_value = var.BUFFERING_INTERVAL
          }
        }
      }
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_log_stream.name
    }
  }

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "firehose-delivery-stream"
  }

  depends_on = [
    time_sleep.iam_propagation
  ]
}

# ---------------------------------------------------------------------------
# Lake Formation permissions — regular Glue catalog mode
# ---------------------------------------------------------------------------

# Lake Formation permissions for database
# Skipped for S3 Tables mode — federated catalog databases are not in the regular Glue catalog
resource "aws_lakeformation_permissions" "db_permission" {
  count = var.CATALOG_ARN == "" ? 1 : 0

  permissions = ["DESCRIBE", "CREATE_TABLE", "ALTER", "DROP"]
  principal   = aws_iam_role.firehose_role.arn

  database {
    name = var.GLUE_DATABASE_NAME
  }

  depends_on = [aws_iam_role.firehose_role]
}

# Lake Formation permissions for tables
# Skipped for S3 Tables mode — federated catalog tables are not in the regular Glue catalog
resource "aws_lakeformation_permissions" "table_permissions" {
  count = var.CATALOG_ARN == "" ? 1 : 0

  principal   = aws_iam_role.firehose_role.arn
  permissions = ["SELECT", "INSERT", "DELETE", "DESCRIBE", "ALTER", "DROP"]

  table {
    database_name = var.GLUE_DATABASE_NAME
    wildcard      = true
  }

  depends_on = [aws_iam_role.firehose_role]
}

# Grant on the S3 Tables namespace (database)
resource "aws_lakeformation_permissions" "s3tables_db_permission" {
  count = var.CATALOG_ARN != "" ? 1 : 0

  principal   = aws_iam_role.firehose_role.arn
  permissions = ["ALL"]

  database {
    catalog_id = local.s3_tables_lf_bucket_id
    name       = var.GLUE_DATABASE_NAME
  }

  depends_on = [aws_iam_role.firehose_role]
}

# Grant on all tables in the S3 Tables namespace
resource "aws_lakeformation_permissions" "s3tables_table_permissions" {
  count = var.CATALOG_ARN != "" ? 1 : 0

  principal   = aws_iam_role.firehose_role.arn
  permissions = ["ALL"]

  table {
    catalog_id    = local.s3_tables_lf_bucket_id
    database_name = var.GLUE_DATABASE_NAME
    wildcard      = true
  }

  depends_on = [aws_iam_role.firehose_role]
}
