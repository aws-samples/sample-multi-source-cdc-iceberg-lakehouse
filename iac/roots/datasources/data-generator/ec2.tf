# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {
  msk_source_topic_list = join(",", [
    "\"${local.MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME}\"",
    "\"${local.MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME}\""
  ])
}

data "aws_ami" "amazon_linux_ecs_neuron" {

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-ecs-neuron-hvm-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "archive_file" "data_generator_source" {

  type        = "zip"
  source_dir  = "${path.module}/generator"
  output_path = "${path.module}/data-generator-source.zip"
  excludes = [
    "target/**",
    ".DS_Store",
    "*.log",
    ".idea/**",
    "*.iml"
  ]
}

resource "aws_s3_object" "data_generator_source" {

  bucket = local.ASSETS_BUCKET
  key    = "data-generator/source.zip"
  source = data.archive_file.data_generator_source.output_path
  etag   = data.archive_file.data_generator_source.output_md5
}

resource "aws_iam_policy" "ec2_iam_policy" {
  // nosemgrep: terraform.lang.security.iam.no-iam-data-exfiltration.no-iam-data-exfiltration:S3 access required for data generator source code
  name        = "${var.APP}-${var.ENV}-data-generator-ec2-iam-policy"
  path        = "/"
  description = "Policy for allowing EC2 to access required services for data generation."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        // nosemgrep:
        Action = [
          "s3:GetObject",
        ]
        Effect   = "Allow"
        Resource = ["${data.aws_s3_bucket.asset_bucket.arn}/data-generator/source.zip"]
      },
      {
        Action = [
          "kms:Decrypt",
        ]
        Effect = "Allow"
        Resource = [
          local.S3_KMS_ARN,
          local.SECRETS_MANAGER_KMS_KEY_ARN
        ]
      },
      {
        // nosemgrep:
        Action = ["secretsmanager:GetSecretValue"]
        Effect = "Allow"
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.APP}-${var.ENV}-aurora-db-secret-*",
          "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.APP}-${var.ENV}-oracle-db-secret-*",
          "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.APP}-${var.ENV}-msk-source-bootstrap-servers-sasl-iam-*",
          "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.APP}-${var.ENV}-cockroach-db-secret-*"
        ]
      },
      {
        Action = [
          "kafka:ListClustersV2",
          "kafka:GetBootstrapBrokers"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka:DescribeCluster",
          "kafka:DescribeClusterV2",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:kafka:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.APP}-${var.ENV}-msk-source-cluster/*",
          "arn:aws:kafka:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:topic/${var.APP}-${var.ENV}-msk-source-cluster/*",
          "arn:aws:kafka:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.APP}-${var.ENV}-msk-ingest-cluster/*",
          "arn:aws:kafka:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:topic/${var.APP}-${var.ENV}-msk-ingest-cluster/*"
        ]
      }
    ]
  })
}

module "ec2" {

  source                 = "../../../templates/modules/ec2"
  APP                    = var.APP
  ENV                    = var.ENV
  instance_name          = "data-generator"
  ami_id                 = data.aws_ami.amazon_linux_ecs_neuron.id
  subnet_id              = local.PRIVATE_SUBNETS[0]
  vpc_security_group_ids = [aws_security_group.data_generator_sg.id]
  public_ip              = false
  user_data = base64gzip(templatefile("${path.module}/ec2-user-data.sh", {
    aws_region    = var.REGION
    assets_bucket = local.ASSETS_BUCKET

    enable_msk       = var.ENABLE_MSK_INTEGRATION
    enable_oracle    = var.ENABLE_ORACLE_INTEGRATION
    enable_aurora    = var.ENABLE_AURORA_INTEGRATION
    enable_cockroach = var.ENABLE_COCKROACH_INTEGRATION

    msk_secret_name       = local.MSK_SECRET_NAME
    msk_cluster_name      = "${var.APP}-${var.ENV}-msk-source-cluster"
    msk_source_topic_list = "(${local.msk_source_topic_list})"

    oracle_secret_name                       = local.ORACLE_SECRET_NAME
    oracle_financial_transactions_table_name = var.ORACLE_FINANCIAL_TRANSACTIONS_TABLE_NAME
    oracle_brokerage_transactions_table_name = var.ORACLE_BROKERAGE_TRANSACTIONS_TABLE_NAME

    aurora_secret_name                       = local.AURORA_SECRET_NAME
    aurora_financial_transactions_table_name = var.AURORA_FINANCIAL_TRANSACTIONS_TABLE_NAME
    aurora_brokerage_transactions_table_name = var.AURORA_BROKERAGE_TRANSACTIONS_TABLE_NAME

    cockroach_secret_name                       = local.COCKROACH_SECRET_NAME
    cockroach_financial_transactions_table_name = var.COCKROACH_FINANCIAL_TRANSACTIONS_TABLE_NAME
    cockroach_brokerage_transactions_table_name = var.COCKROACH_BROKERAGE_TRANSACTIONS_TABLE_NAME
  }))
}

resource "aws_ssm_parameter" "data_generator_host" {

  name        = "/${var.APP}/${var.ENV}/data-generator-host"
  description = "Data generator EC2 host"
  type        = "SecureString"
  value       = module.ec2.private_ip
  key_id      = data.aws_kms_key.ssm_kms_key.arn
}

resource "aws_iam_role_policy_attachment" "attachment_1" {

  policy_arn = aws_iam_policy.ec2_iam_policy.arn
  role       = module.ec2.iam_role_name
}
