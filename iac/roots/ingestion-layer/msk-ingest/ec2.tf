# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {
  topic_list = join(",", [
    "\"${var.ORACLE_FINANCIAL_TRANSACTIONS_TOPIC_NAME}\"",
    "\"${var.AURORA_FINANCIAL_TRANSACTIONS_TOPIC_NAME}\"",
    "\"${var.COCKROACH_FINANCIAL_TRANSACTIONS_TOPIC_NAME}\"",
    "\"${var.ORACLE_BROKERAGE_TRANSACTIONS_TOPIC_NAME}\"",
    "\"${var.AURORA_BROKERAGE_TRANSACTIONS_TOPIC_NAME}\"",
    "\"${var.COCKROACH_BROKERAGE_TRANSACTIONS_TOPIC_NAME}\""
  ])
}

resource "aws_iam_policy" "ec2_iam_policy" {

  name        = "${var.APP}-${var.ENV}-msk-ingest-config-ec2-iam-policy"
  path        = "/"
  description = "Policy for allowing EC2 to access MSK and Secrets Manager."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
          "kafka-cluster:ReadData",
        ]
        Effect = "Allow"
        Resource = [
          "${module.msk_cluster.cluster_arn}",
          "arn:aws:kafka:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:topic/${module.msk_cluster.cluster_name}/*",
        ]
      },
      {
        // nosemgrep:
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:AmazonMSK_${module.msk_cluster.cluster_name}-credentials-*"
        ]
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Effect = "Allow"
        Resource = [
          "${data.aws_kms_key.secrets_manager_key.arn}"
        ]
      },
    ]
  })
}

module "ec2" {

  source                 = "../../../templates/modules/ec2"
  APP                    = var.APP
  ENV                    = var.ENV
  instance_name          = "msk-ingest-config"
  subnet_id              = local.PRIVATE_SUBNETS[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  public_ip              = false
  user_data = templatefile("${path.module}/ec2-user-data.sh", {
    msk_cluster_name     = "${module.msk_cluster.cluster_name}"
    kafka_client_version = "${var.KAFKA_CLIENT_VERSION}"
    aws_region           = "${var.REGION}"
    topic_list           = "(${local.topic_list})"
  })

  depends_on = [module.msk_cluster]
}

resource "aws_iam_role_policy_attachment" "attachment_1" {

  policy_arn = aws_iam_policy.ec2_iam_policy.arn
  role       = module.ec2.iam_role_name
}

# Store MSK instance IP address in SSM Parameter Store
resource "aws_ssm_parameter" "msk_instance_host" {

  name        = "/${var.APP}/${var.ENV}/msk-ingest-config-host"
  description = "MSK ingest config host private IP address"
  type        = "SecureString"
  value       = module.ec2.private_ip
  key_id      = data.aws_kms_key.secrets_manager_key.arn

  tags = {
    Application = var.APP
    Environment = var.ENV
  }
}
