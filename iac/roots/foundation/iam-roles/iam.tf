# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# DMS requires specific IAM roles to be created before replication instances can be created
# See: https://docs.aws.amazon.com/dms/latest/userguide/security-iam.html#CHAP_Security.APIRole
data "aws_iam_policy_document" "dms_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

# Combined endpoint access policy including MSK permissions
data "aws_iam_policy_document" "dms_msk_access" {
  #checkov:skip=CKV_AWS_356:DMS requires wildcard resources for MSK cluster discovery and access

  statement {
    effect = "Allow"
    actions = [
      "kafka:DescribeCluster",
      "kafka:GetBootstrapBrokers",
      "kafka:ListClusters"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "kafka-cluster:Connect",
      "kafka-cluster:AlterCluster",
      "kafka-cluster:DescribeCluster",
      "kafka-cluster:*Topic*",
      "kafka-cluster:WriteData",
      "kafka-cluster:ReadData"
    ]
    resources = [
      "arn:aws:kafka:${local.region}:${local.account_id}:cluster/${var.MSK_SOURCE_CLUSTER_NAME}*",
      "arn:aws:kafka:${local.region}:${local.account_id}:topic/${var.MSK_SOURCE_CLUSTER_NAME}*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kafka-cluster:AlterGroup",
      "kafka-cluster:DescribeGroup"
    ]
    resources = [
      "arn:aws:kafka:${local.region}:${local.account_id}:group/${var.MSK_SOURCE_CLUSTER_NAME}/*"
    ]
  }
}

// Glue Role
resource "aws_iam_role" "aws_iam_glue_role" {

  name = "${var.APP}-${var.ENV}-glue-role"

  tags = {
    Application = var.APP
    Environment = var.ENV
    Usage       = "glue"
  }

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_glue_service_attachment" {

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  role       = aws_iam_role.aws_iam_glue_role.id
}

resource "aws_iam_role_policy_attachment" "glue_s3_tables_full_access_attachment" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonS3TablesFullAccess"
  role       = aws_iam_role.aws_iam_glue_role.id
}

resource "aws_iam_role_policy_attachment" "glue_s3_full_access_attachment" {

  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.aws_iam_glue_role.id
}

resource "aws_iam_role_policy" "glue_policy" {
  #checkov:skip=CKV_AWS_290:Glue service requires broad permissions for data lake operations
  #checkov:skip=CKV_AWS_355:Glue service requires wildcard resources for catalog and job operations

  name = "${var.APP}-${var.ENV}-glue-policy"
  role = aws_iam_role.aws_iam_glue_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.APP}-${var.ENV}-price-data-primary/*",
          "arn:aws:s3:::${var.APP}-${var.ENV}-price-hive-primary/*",
          "arn:aws:s3:::${var.APP}-${var.ENV}-price-iceberg-primary/*",
          "arn:aws:s3:::${var.APP}-${var.ENV}-glue-scripts-primary/*",
          "arn:aws:s3:::${var.APP}-${var.ENV}-glue-dependencies-primary/*",
          "arn:aws:s3:::${var.APP}-${var.ENV}-glue-jars-primary/*",
          "arn:aws:s3:::${var.APP}-${var.ENV}-glue-spark-logs-primary/*",
          "arn:aws:s3:::${var.APP}-${var.ENV}-glue-temp-primary/*",
          "arn:aws:s3:::${var.APP}-${var.ENV}-athena-output-primary/*",
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:AssociateKmsKey",
        ],
        "Resource" : "arn:aws:logs:${var.AWS_PRIMARY_REGION}:${local.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = ["arn:aws:kms:${var.AWS_PRIMARY_REGION}:${local.account_id}:*"]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "*"
        ]
        Condition = {
          StringEquals = {
            "secretsmanager:ResourceTag/Usage" : [
              "splunk",
              "snowflake"
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3tables:CreateTableBucket",
          "s3tables:GetTableBucket",
          "s3tables:ListTableBuckets",
          "s3tables:CreateNamespace",
          "s3tables:ListNamespace",
          "s3tables:GetNamespace",
          "s3tables:DeleteNamespace",
          "s3tables:GetTableMetadataLocation",
          "s3tables:UpdateTableMetadataLocation",
          "s3tables:DeleteTableBucket",
          "s3tables:CreateTable",
          "s3tables:GetTable",
          "s3tables:ListTables",
          "s3tables:RenameTable",
          "s3tables:GetTableData",
          "s3tables:PutTableData",
          "s3tables:*",
        ]
        Resource = "arn:aws:s3tables:${local.region}:${local.account_id}:bucket/*"
      },
      {
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess",
          "lakeformation:GetTemporaryGlueTableCredentials",
          "lakeformation:GetTemporaryGluePartitionCredentials"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "datazone:postLineageEvent",
          "datazone:postTimeSeriesDataPoints",
          "datazone:SearchListings"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow",
        Action = [
          "cloudtrail:LookupEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "lakeformation:*"
        ],
        Resource = "*"
      },
      {
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData",
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup",
          "kafka-cluster:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "kafka:DescribeCluster",
          "kafka:GetBootstrapBrokers",
          "kafka:ListClusters",
          "kafka:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka:DescribeCluster",
          "kafka:GetBootstrapBrokers",
          "kafka:ListClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${data.aws_caller_identity.current.account_id}:cluster/${var.APP}-${var.ENV}-msk-source-cluster/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${data.aws_caller_identity.current.account_id}:topic/${var.APP}-${var.ENV}-msk-source-cluster/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "arn:aws:kafka:${var.AWS_PRIMARY_REGION}:${data.aws_caller_identity.current.account_id}:group/${var.APP}-${var.ENV}-msk-source-cluster/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${var.AWS_PRIMARY_REGION}:${data.aws_caller_identity.current.account_id}:parameter/${var.APP}/${var.ENV}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.AWS_PRIMARY_REGION}:${data.aws_caller_identity.current.account_id}:secret:${var.APP}-${var.ENV}-msk-source-bootstrap-servers-sasl-iam-*"
        ]
      }
    ]
  })
}

# Lake Formation Service Role
resource "aws_iam_role" "lakeformation_service_role" {

  name = "${var.APP}-${var.ENV}-lakeformation-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LakeFormationDataAccessPolicy"
        Effect = "Allow"
        Action = ["sts:AssumeRole",
          "sts:SetContext",
        "sts:SetSourceIdentity"]
        Principal = {
          Service = [
            "lakeformation.amazonaws.com",
            "glue.amazonaws.com",
            "athena.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# Lake Formation Service Role Policy
resource "aws_iam_role_policy" "lakeformation_service_role_policy" {

  name = "${var.APP}-${var.ENV}-lakeformation-service-role-policy"
  role = aws_iam_role.lakeformation_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LakeFormationServiceRole"
        Effect = "Allow"
        // nosemgrep:
        Action = [
          "s3tables:ListTableBuckets",
          "s3tables:CreateTableBucket",
          "s3tables:GetTableBucket",
          "s3tables:CreateNamespace",
          "s3tables:GetNamespace",
          "s3tables:ListNamespaces",
          "s3tables:DeleteNamespace",
          "s3tables:DeleteTableBucket",
          "s3tables:CreateTable",
          "s3tables:DeleteTable",
          "s3tables:GetTable",
          "s3tables:ListTables",
          "s3tables:RenameTable",
          "s3tables:UpdateTableMetadataLocation",
          "s3tables:GetTableMetadataLocation",
          "s3tables:GetTableData",
          "s3tables:PutTableData",
          "glue:CreateDatabase",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:GetTable",
          "glue:GetTables",
          "lakeformation:RegisterResource",
          "lakeformation:GetDataLakeSettings",
          "lakeformation:PutDataLakeSettings",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource : [
          "arn:aws:s3tables:${local.region}:${local.account_id}:bucket/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = ["arn:aws:kms:${var.AWS_PRIMARY_REGION}:${local.account_id}:*"]
      }
    ]
  })
}

resource "aws_lakeformation_data_lake_settings" "cross_account_settings" {
  parameters = {
    CROSS_ACCOUNT_VERSION = "4"
  }
}

# CockroachDB IAM Role
resource "aws_iam_role" "cockroachdb_role" {
  name = "${var.APP}-${var.ENV}-cockroachdb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "cockroachdb"
  }
}

# CockroachDB IAM Instance Profile
resource "aws_iam_instance_profile" "cockroachdb_profile" {
  name = "${var.APP}-${var.ENV}-cockroachdb-profile"
  role = aws_iam_role.cockroachdb_role.name

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "cockroachdb"
  }
}

# CockroachDB IAM Policy for SSM access
resource "aws_iam_role_policy" "cockroachdb_ssm_policy" {
  name = "${var.APP}-${var.ENV}-cockroachdb-ssm-policy"
  role = aws_iam_role.cockroachdb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ssm:${var.AWS_PRIMARY_REGION}:${local.account_id}:parameter/${var.APP}/${var.ENV}/*"
      },
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach AmazonSSMManagedInstanceCore policy for SSM Session Manager
resource "aws_iam_role_policy_attachment" "cockroachdb_ssm_managed" {
  role       = aws_iam_role.cockroachdb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# SSM Parameters for CockroachDB IAM resources
resource "aws_ssm_parameter" "cockroachdb_role_arn" {
  #checkov:skip=CKV2_AWS_34:SSM parameter encryption not required for non-sensitive role ARN data
  name        = "/${var.APP}/${var.ENV}/cockroachdb-role-arn"
  description = "CockroachDB IAM role ARN"
  type        = "String"
  value       = aws_iam_role.cockroachdb_role.arn

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "cockroachdb"
  }
}

resource "aws_ssm_parameter" "cockroachdb_role_name" {
  #checkov:skip=CKV2_AWS_34:SSM parameter encryption not required for non-sensitive role name data
  name        = "/${var.APP}/${var.ENV}/cockroachdb-role-name"
  description = "CockroachDB IAM role name"
  type        = "String"
  value       = aws_iam_role.cockroachdb_role.name

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "cockroachdb"
  }
}

resource "aws_ssm_parameter" "cockroachdb_instance_profile_name" {
  #checkov:skip=CKV2_AWS_34:SSM parameter encryption not required for non-sensitive instance profile name data
  name        = "/${var.APP}/${var.ENV}/cockroachdb-instance-profile-name"
  description = "CockroachDB IAM instance profile name"
  type        = "String"
  value       = aws_iam_instance_profile.cockroachdb_profile.name

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "cockroachdb"
  }
}

resource "aws_ssm_parameter" "cockroachdb_instance_profile_arn" {
  #checkov:skip=CKV2_AWS_34:SSM parameter encryption not required for non-sensitive instance profile ARN data
  name        = "/${var.APP}/${var.ENV}/cockroachdb-instance-profile-arn"
  description = "CockroachDB IAM instance profile ARN"
  type        = "String"
  value       = aws_iam_instance_profile.cockroachdb_profile.arn

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "cockroachdb"
  }
}

# DMS VPC Role - Required for VPC management
resource "aws_iam_role" "dms_vpc_role" {

  name               = "dms-vpc-role"
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  description        = "Allows DMS to manage VPC resources"

  tags = {
    Name = "${var.APP}-${var.ENV}-vpc-role"
  }
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role_policy" {

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = aws_iam_role.dms_vpc_role.name
}

# DMS CloudWatch Logs Role - Required for logging
resource "aws_iam_role" "dms_cloudwatch_logs_role" {

  name               = "dms-cloudwatch-logs-role"
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  description        = "Allows DMS to write to CloudWatch Logs"

  tags = {
    Name = "${var.APP}-${var.ENV}-cloudwatch-logs-role"
  }
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_logs_role_policy" {

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
  role       = aws_iam_role.dms_cloudwatch_logs_role.name
}

# DMS Access for Endpoint Role - Required for endpoint access
resource "aws_iam_role" "dms_access_for_endpoint" {

  name               = "dms-access-for-endpoint"
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  description        = "Allows DMS to access endpoints and MSK"

  tags = {
    Name = "${var.APP}-${var.ENV}-access-for-endpoint"
  }
}

resource "aws_iam_role_policy" "dms_msk_access" {

  name   = "${var.APP}-${var.ENV}-endpoint-access-policy"
  role   = aws_iam_role.dms_access_for_endpoint.id
  policy = data.aws_iam_policy_document.dms_msk_access.json
}
