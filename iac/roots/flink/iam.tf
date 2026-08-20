# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# -----------------------------------------------------------------------------
# Managed Flink Service Execution Role
#
# Assumed by kinesisanalytics.amazonaws.com. Grants access to:
#   - Glue Data Catalog (Iceberg catalog)
#   - S3 (Iceberg warehouse + assets bucket where the app JAR lives)
#   - MSK (connect / read data / describe via IAM auth)
#   - KMS (decrypt SSM SecureStrings, data keys for S3)
#   - CloudWatch Logs
#   - VPC ENI management (required for VPC-attached apps)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "flink_role" {
  name = "${var.APP}-${var.ENV}-flink-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "kinesisanalytics.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Application = var.APP
    Environment = var.ENV
    Usage       = "managed-flink"
  }
}

resource "aws_iam_role_policy" "flink_policy" {
  #checkov:skip=CKV_AWS_355:VPC operations require Resource="*" - AWS Managed Flink rejects scoped resources at CreateApplication validation
  #checkov:skip=CKV_AWS_290:Resource="*" required by AWS for VPC-attached Managed Flink applications
  #checkov:skip=CKV_AWS_289:ec2:CreateNetworkInterfacePermission requires Resource="*" per AWS Managed Flink docs
  name = "${var.APP}-${var.ENV}-flink-policy"
  role = aws_iam_role.flink_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ---- Glue Catalog (Iceberg) --------------------------------------------
      {
        Sid    = "GlueCatalog"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchCreatePartition",
          "glue:BatchGetPartition"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:catalog",
          "arn:aws:glue:${local.region}:${local.account_id}:database/*",
          "arn:aws:glue:${local.region}:${local.account_id}:table/*/*"
        ]
      },
      # ---- S3: Iceberg warehouse (read/write) + assets bucket (read JAR) -----
      {
        Sid    = "S3IcebergAndAssets"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${local.iceberg_datalake_bucket_name}",
          "arn:aws:s3:::${local.iceberg_datalake_bucket_name}/*",
          "arn:aws:s3:::${local.assets_bucket_name}",
          "arn:aws:s3:::${local.assets_bucket_name}/*"
        ]
      },
      # ---- S3 Tables (managed Iceberg via REST catalog) ---------------------
      {
        Sid    = "S3TablesAccess"
        Effect = "Allow"
        Action = [
          "s3tables:GetTable",
          "s3tables:GetTableBucket",
          "s3tables:GetNamespace",
          "s3tables:ListTables",
          "s3tables:ListNamespaces",
          "s3tables:CreateTable",
          "s3tables:CreateNamespace",
          "s3tables:PutTableData",
          "s3tables:GetTableData",
          "s3tables:GetTableMetadataLocation",
          "s3tables:UpdateTableMetadataLocation"
        ]
        Resource = [
          local.s3_table_bucket_arn,
          "${local.s3_table_bucket_arn}/*"
        ]
      },
      # ---- MSK (IAM auth) ----------------------------------------------------
      {
        Sid    = "MSKClusterAccess"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = [
          "arn:aws:kafka:${local.region}:${local.account_id}:cluster/${var.APP}-${var.ENV}-msk-ingest-cluster/*",
          "arn:aws:kafka:${local.region}:${local.account_id}:cluster/${var.APP}-${var.ENV}-msk-source-cluster/*"
        ]
      },
      {
        Sid    = "MSKTopicAndGroupAccess"
        Effect = "Allow"
        Action = [
          "kafka-cluster:ReadData",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup"
        ]
        Resource = [
          "arn:aws:kafka:${local.region}:${local.account_id}:topic/${var.APP}-${var.ENV}-msk-ingest-cluster/*",
          "arn:aws:kafka:${local.region}:${local.account_id}:group/${var.APP}-${var.ENV}-msk-ingest-cluster/*",
          "arn:aws:kafka:${local.region}:${local.account_id}:topic/${var.APP}-${var.ENV}-msk-source-cluster/*",
          "arn:aws:kafka:${local.region}:${local.account_id}:group/${var.APP}-${var.ENV}-msk-source-cluster/*"
        ]
      },
      # ---- KMS ---------------------------------------------------------------
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${local.region}:${local.account_id}:key/*"
      },
      # ---- CloudWatch Logs ---------------------------------------------------
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      },
      # ---- VPC ENI operations (Managed Flink validates these upfront, so
      #      Resource and Condition scoping that AWS doesn't expect causes
      #      "service does not have necessary privileges" errors at
      #      CreateApplication time. AWS's documented template uses
      #      Resource = "*" with no conditions for ENI ops.) ----------------
      {
        Sid    = "VPCManageENI"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      # ---- VPC Describe (cannot be scoped per AWS docs) ------------------------
      {
        Sid    = "VPCDescribe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeDhcpOptions"
        ]
        Resource = "*"
      }
    ]
  })
}

# Publish role ARN to SSM for downstream consumers
resource "aws_ssm_parameter" "flink_role_arn" {
  #checkov:skip=CKV2_AWS_34:SSM parameter encryption not required for non-sensitive role ARN data
  name  = "/${var.APP}/${var.ENV}/flink-role-arn"
  type  = "String"
  value = aws_iam_role.flink_role.arn

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "flink"
  }
}
