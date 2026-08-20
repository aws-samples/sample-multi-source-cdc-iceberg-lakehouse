# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {
  # MSK only accepts 2 or 3 subnets, so take the first 3 if we have more than 3
  MSK_SUBNETS       = length(var.SUBNET_IDS) > 3 ? slice(var.SUBNET_IDS, 0, 3) : var.SUBNET_IDS
  CLUSTER_FULL_NAME = "${var.APP}-${var.ENV}-${var.CLUSTER_NAME}"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

#
# MSK Secret Policy
#
data "aws_iam_policy_document" "msk_secret_policy" {
  #checkov:skip=CKV_AWS_108:MSK service requires secret access for SASL/SCRAM authentication
  count = var.ENABLE_SASL_SCRAM_AUTH && var.SASL_SCRAM_USERNAME != "" ? 1 : 0
  statement {
    sid    = "AWSKafkaResourcePolicy"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["kafka.amazonaws.com"]
    }

    actions   = ["secretsmanager:getSecretValue"]
    resources = [aws_secretsmanager_secret.msk_secret[0].arn]
  }
}

resource "aws_msk_configuration" "msk_config" {
  name              = "${local.CLUSTER_FULL_NAME}-config"
  description       = "Auto-topic creation, deletion enabled, and replication settings for high availability"
  server_properties = <<PROPERTIES
        auto.create.topics.enable = true
        delete.topic.enable = true
        default.replication.factor = 3
        min.insync.replicas = 2
    PROPERTIES
}

#
# MSK Cluster
#
resource "aws_msk_cluster" "cluster" {

  cluster_name           = local.CLUSTER_FULL_NAME
  kafka_version          = var.KAFKA_VERSION
  number_of_broker_nodes = length(local.MSK_SUBNETS)

  configuration_info {
    arn      = aws_msk_configuration.msk_config.arn
    revision = 1
  }

  broker_node_group_info {
    instance_type   = var.INSTANCE_TYPE
    client_subnets  = local.MSK_SUBNETS
    security_groups = var.SECURITY_GROUP_IDS

    storage_info {
      ebs_storage_info {
        volume_size = var.STORAGE_SIZE
      }
    }
    connectivity_info {
      public_access {
        type = "DISABLED"
      }
      vpc_connectivity {
        client_authentication {
          sasl {
            iam = true
          }
        }
      }
    }
  }
  encryption_info {
    encryption_at_rest_kms_key_arn = var.KAFKA_KMS_KEY_ARN
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    unauthenticated = false
    sasl {
      iam   = true
      scram = var.ENABLE_SASL_SCRAM_AUTH
    }
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  enhanced_monitoring = var.ENHANCED_MONITORING_LEVEL

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_logs.name
      }
    }
  }

  tags = {
    Name        = local.CLUSTER_FULL_NAME
    Application = var.APP
    Environment = var.ENV
  }

  depends_on = [
    aws_cloudwatch_log_group.msk_logs,
    aws_msk_configuration.msk_config
  ]
}

#
# Cloudwatch log group for MSK
#
resource "aws_cloudwatch_log_group" "msk_logs" { // nosemgrep:
  #checkov:skip=CKV_AWS_338:Log retention set to 7 days for cost optimization in this sample
  #checkov:skip=CKV_AWS_158:CloudWatch log encryption not required for this sample
  name              = "/${var.APP}/${var.ENV}/msk/${local.CLUSTER_FULL_NAME}"
  retention_in_days = 7

  tags = {
    Name        = "${local.CLUSTER_FULL_NAME}-logs"
    Application = var.APP
    Environment = var.ENV
  }
}

# Generate random password for SASL SCRAM authentication
resource "random_password" "msk_password" {

  count = var.ENABLE_SASL_SCRAM_AUTH && var.SASL_SCRAM_USERNAME != "" ? 1 : 0

  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

#
# Secrets Manager for SASL/SCRAM credentials using secrets-manager module
# Name has to start with "AmazonMSK_ for the cluster to register it"
#
resource "aws_secretsmanager_secret" "msk_secret" {
  #checkov:skip=CKV2_AWS_57:Automatic rotation not required for MSK SASL credentials in this sample

  count                   = var.ENABLE_SASL_SCRAM_AUTH && var.SASL_SCRAM_USERNAME != "" ? 1 : 0
  name                    = "AmazonMSK_${local.CLUSTER_FULL_NAME}-credentials"
  description             = "SASL/SCRAM credentials for MSK cluster ${local.CLUSTER_FULL_NAME}"
  kms_key_id              = var.SECRETS_MANAGER_KMS_KEY_ARN
  recovery_window_in_days = 0 # Allow immediate deletion of the secret
}

resource "aws_secretsmanager_secret_version" "msk_secret_version" {

  count     = var.ENABLE_SASL_SCRAM_AUTH && var.SASL_SCRAM_USERNAME != "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.msk_secret[0].id
  secret_string = jsonencode({
    username = var.SASL_SCRAM_USERNAME,
    password = random_password.msk_password[0].result
  })
}

#
# MSK SCRAM Secret Association
#
resource "aws_msk_scram_secret_association" "msk_scram" {

  count           = var.ENABLE_SASL_SCRAM_AUTH && var.SASL_SCRAM_USERNAME != "" ? 1 : 0
  cluster_arn     = aws_msk_cluster.cluster.arn
  secret_arn_list = [aws_secretsmanager_secret.msk_secret[0].arn]

  depends_on = [aws_secretsmanager_secret_version.msk_secret_version]
}

resource "aws_secretsmanager_secret_policy" "msk_secretsmanager_secret_policy" {

  count      = var.ENABLE_SASL_SCRAM_AUTH && var.SASL_SCRAM_USERNAME != "" ? 1 : 0
  secret_arn = aws_secretsmanager_secret.msk_secret[0].arn
  policy     = data.aws_iam_policy_document.msk_secret_policy[0].json
}
