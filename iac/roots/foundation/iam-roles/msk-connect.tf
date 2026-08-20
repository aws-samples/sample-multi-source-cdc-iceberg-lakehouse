# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# -----------------------------------------------------------------------------
# MSK Connect IAM Roles (Path 2: Debezium Source Connectors)
# -----------------------------------------------------------------------------

# =============================================================================
# Role 1: Debezium Source Connector Execution Role
# =============================================================================

resource "aws_iam_role" "msk_connect_debezium_role" {
  name = "${var.APP}-${var.ENV}-msk-connect-debezium-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "kafkaconnect.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Application = var.APP
    Environment = var.ENV
    Usage       = "msk-connect-debezium"
  }
}

resource "aws_iam_role_policy" "msk_connect_debezium_policy" {
  name = "${var.APP}-${var.ENV}-msk-connect-debezium-policy"
  role = aws_iam_role.msk_connect_debezium_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # MSK Cluster Access (IAM auth)
      {
        Sid    = "MSKClusterAccess"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:AlterCluster"
        ]
        Resource = "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:cluster/${var.APP}-${var.ENV}-msk-ingest-cluster/*"
      },
      {
        Sid    = "MSKTopicAccess"
        Effect = "Allow"
        Action = [
          "kafka-cluster:CreateTopic",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:AlterTopic",
          "kafka-cluster:DeleteTopic",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:topic/${var.APP}-${var.ENV}-msk-ingest-cluster/*"
      },
      {
        Sid    = "MSKGroupAccess"
        Effect = "Allow"
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:group/${var.APP}-${var.ENV}-msk-ingest-cluster/*"
      },
      # S3 Plugin Bucket Access
      {
        Sid    = "S3PluginAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.APP}-${var.ENV}-msk-connect-plugins-primary",
          "arn:aws:s3:::${var.APP}-${var.ENV}-msk-connect-plugins-primary/*"
        ]
      },
      # Secrets Manager — DB credentials
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.AWS_PRIMARY_REGION}:${local.account_id}:secret:*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Application" = var.APP
          }
        }
      },
      # SSM Parameter Access — connection details
      {
        Sid    = "SSMAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.AWS_PRIMARY_REGION}:${local.account_id}:parameter/${var.APP}/${var.ENV}/*"
      },
      # KMS Decrypt — for encrypted SSM parameters and secrets
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${var.AWS_PRIMARY_REGION}:${local.account_id}:key/*"
      },
      # CloudWatch Logs
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.AWS_PRIMARY_REGION}:${local.account_id}:log-group:/aws/msk-connect/${var.APP}-${var.ENV}-*"
      },
    ]
  })
}

# =============================================================================
# Role 3 & 4: CockroachDB Changefeed IAM Roles
# CockroachDB EC2 instances assume these roles to write changefeeds to MSK
# Ingest via IAM auth. Used by both Path 1 (Firehose) and Path 2 (Apache Flink).
# =============================================================================

resource "aws_iam_role" "cockroach_financial_msk_role" {
  name = "${var.APP}-${var.ENV}-cockroach-financial-msk-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
          AWS     = aws_iam_role.cockroachdb_role.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Application = var.APP
    Environment = var.ENV
    Usage       = "cockroach-changefeed-financial"
  }
}

resource "aws_iam_role_policy" "cockroach_financial_msk_policy" {
  name = "${var.APP}-${var.ENV}-cockroach-financial-msk-policy"
  role = aws_iam_role.cockroach_financial_msk_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:cluster/${var.APP}-${var.ENV}-msk-ingest-cluster/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:*Topic",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = [
          "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:cluster/${var.APP}-${var.ENV}-msk-ingest-cluster/*",
          "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:topic/${var.APP}-${var.ENV}-msk-ingest-cluster/*/crdb_fin"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = [
          "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:cluster/${var.APP}-${var.ENV}-msk-ingest-cluster/*",
          "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:group/${var.APP}-${var.ENV}-msk-ingest-cluster/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "cockroach_brokerage_msk_role" {
  name = "${var.APP}-${var.ENV}-cockroach-brokerage-msk-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
          AWS     = aws_iam_role.cockroachdb_role.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Application = var.APP
    Environment = var.ENV
    Usage       = "cockroach-changefeed-brokerage"
  }
}

resource "aws_iam_role_policy" "cockroach_brokerage_msk_policy" {
  name = "${var.APP}-${var.ENV}-cockroach-brokerage-msk-policy"
  role = aws_iam_role.cockroach_brokerage_msk_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:cluster/${var.APP}-${var.ENV}-msk-ingest-cluster/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:*Topic",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = [
          "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:cluster/${var.APP}-${var.ENV}-msk-ingest-cluster/*",
          "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:topic/${var.APP}-${var.ENV}-msk-ingest-cluster/*/crdb_brk"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = [
          "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:cluster/${var.APP}-${var.ENV}-msk-ingest-cluster/*",
          "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${local.account_id}:group/${var.APP}-${var.ENV}-msk-ingest-cluster/*"
        ]
      }
    ]
  })
}

# CockroachDB EC2 role — sts:AssumeRole for changefeed MSK roles
resource "aws_iam_role_policy" "cockroachdb_assume_msk_roles" {
  name = "${var.APP}-${var.ENV}-cockroachdb-assume-msk-roles"
  role = aws_iam_role.cockroachdb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          aws_iam_role.cockroach_financial_msk_role.arn,
          aws_iam_role.cockroach_brokerage_msk_role.arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# SSM Parameters — share role ARNs with connector roots
# -----------------------------------------------------------------------------

resource "aws_ssm_parameter" "msk_connect_debezium_role_arn" {
  #checkov:skip=CKV2_AWS_34:SSM parameter encryption not required for non-sensitive role ARN data
  name  = "/${var.APP}/${var.ENV}/msk-connect-debezium-role-arn"
  type  = "String"
  value = aws_iam_role.msk_connect_debezium_role.arn

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "msk-connect"
  }
}


