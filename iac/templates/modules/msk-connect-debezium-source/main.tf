# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  connector_full_name = "${var.APP}-${var.ENV}-dbz-${var.CONNECTOR_NAME}"

  # Plain JsonConverter worker config
  worker_config_plain = <<-EOT
    key.converter=org.apache.kafka.connect.json.JsonConverter
    key.converter.schemas.enable=${var.SCHEMAS_ENABLE}
    value.converter=org.apache.kafka.connect.json.JsonConverter
    value.converter.schemas.enable=${var.SCHEMAS_ENABLE}
  EOT
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "connector_logs" {
  #checkov:skip=CKV_AWS_338:Log retention configured per variable for cost optimization in this sample
  #checkov:skip=CKV_AWS_158:CloudWatch log encryption not required for this sample
  name              = "/aws/msk-connect/${local.connector_full_name}"
  retention_in_days = var.LOG_RETENTION_DAYS

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "msk-connect-debezium-${var.CONNECTOR_NAME}"
  }
}

# -----------------------------------------------------------------------------
# Custom Plugin — Debezium connector JAR packaged as ZIP
# -----------------------------------------------------------------------------

resource "aws_mskconnect_custom_plugin" "debezium" {
  name         = "${local.connector_full_name}-plugin"
  content_type = "ZIP"

  location {
    s3 {
      bucket_arn = var.PLUGIN_S3_BUCKET_ARN
      file_key   = var.PLUGIN_S3_KEY
    }
  }

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "msk-connect-plugin"
  }
}

# -----------------------------------------------------------------------------
# Worker Configuration
# -----------------------------------------------------------------------------

resource "aws_mskconnect_worker_configuration" "debezium" {
  name                    = "${local.connector_full_name}-worker-config"
  properties_file_content = local.worker_config_plain

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "msk-connect-worker-config"
  }
}

# -----------------------------------------------------------------------------
# MSK Connect Connector
# -----------------------------------------------------------------------------

resource "aws_mskconnect_connector" "debezium" {
  name                 = local.connector_full_name
  kafkaconnect_version = var.KAFKACONNECT_VERSION

  capacity {
    dynamic "autoscaling" {
      for_each = var.USE_PROVISIONED_CAPACITY ? [] : [1]
      content {
        min_worker_count = var.MIN_WORKERS
        max_worker_count = var.MAX_WORKERS
        mcu_count        = var.MCU_COUNT

        scale_in_policy {
          cpu_utilization_percentage = 20
        }

        scale_out_policy {
          cpu_utilization_percentage = 80
        }
      }
    }

    dynamic "provisioned_capacity" {
      for_each = var.USE_PROVISIONED_CAPACITY ? [1] : []
      content {
        worker_count = var.WORKER_COUNT
        mcu_count    = var.MCU_COUNT
      }
    }
  }

  connector_configuration = var.CONNECTOR_CONFIG

  kafka_cluster {
    apache_kafka_cluster {
      bootstrap_servers = var.MSK_BOOTSTRAP_SERVERS

      vpc {
        security_groups = var.VPC_SECURITY_GROUP_IDS
        subnets         = var.VPC_SUBNET_IDS
      }
    }
  }

  kafka_cluster_client_authentication {
    authentication_type = "IAM"
  }

  kafka_cluster_encryption_in_transit {
    encryption_type = "TLS"
  }

  plugin {
    custom_plugin {
      arn      = aws_mskconnect_custom_plugin.debezium.arn
      revision = aws_mskconnect_custom_plugin.debezium.latest_revision
    }
  }

  worker_configuration {
    arn      = aws_mskconnect_worker_configuration.debezium.arn
    revision = aws_mskconnect_worker_configuration.debezium.latest_revision
  }

  service_execution_role_arn = var.EXECUTION_ROLE_ARN

  log_delivery {
    worker_log_delivery {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.connector_logs.name
      }
    }
  }

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "msk-connect-debezium-${var.CONNECTOR_NAME}"
  }
}
