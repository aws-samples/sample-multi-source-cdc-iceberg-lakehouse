# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.region
  name_prefix = "${var.APP}-${var.ENV}"
  tags = {
    Application = var.APP
    Environment = var.ENV
  }
}

# Aurora - Get connection details from SSM Parameter Store (created by Aurora module)
data "aws_ssm_parameter" "aurora_cluster_endpoint" {
  name = "/${var.APP}/${var.ENV}/aurora-cluster-endpoint"
}

data "aws_ssm_parameter" "aurora_cluster_port" {
  name = "/${var.APP}/${var.ENV}/aurora-cluster-port"
}

data "aws_ssm_parameter" "aurora_database_name" {
  name = "/${var.APP}/${var.ENV}/aurora-database-name"
}

data "aws_ssm_parameter" "msk_aurora_financial_transactions_topic" {
  name = "/${var.APP}/${var.ENV}/${var.AURORA_FINANCIAL_TOPIC_NAME_PARAMETER}"
}

data "aws_ssm_parameter" "msk_aurora_brokerage_transactions_topic" {
  name = "/${var.APP}/${var.ENV}/${var.AURORA_BROKERAGE_TOPIC_NAME_PARAMETER}"
}

# Aurora - Get credentials from Secrets Manager (created by Aurora module)
data "aws_secretsmanager_secret" "aurora_credentials" {
  name = "${var.APP}-${var.ENV}-aurora-db-secret"
}

data "aws_secretsmanager_secret_version" "aurora_credentials" {
  secret_id = data.aws_secretsmanager_secret.aurora_credentials.id
}

locals {
  aurora_credentials = jsondecode(data.aws_secretsmanager_secret_version.aurora_credentials.secret_string)
  aurora_endpoint    = data.aws_ssm_parameter.aurora_cluster_endpoint.value
  aurora_port        = tonumber(data.aws_ssm_parameter.aurora_cluster_port.value)
  aurora_database    = data.aws_ssm_parameter.aurora_database_name.value

  # Combined DMS table mappings for Aurora - Routes both transaction types to respective topics
  aurora_table_mappings = jsonencode({
    rules = [
      # Selection rules - specify which tables to replicate
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "select-financial-table"
        object-locator = {
          schema-name = "public"
          table-name  = var.FINANCIAL_TRANSACTIONS_TABLE_NAME
        }
        rule-action = "include"
      },
      {
        rule-type = "selection"
        rule-id   = "2"
        rule-name = "select-brokerage-table"
        object-locator = {
          schema-name = "public"
          table-name  = var.BROKERAGE_TRANSACTIONS_TABLE_NAME
        }
        rule-action = "include"
      },
      # Object mapping rules - route tables to specific Kafka topics
      {
        rule-type = "object-mapping"
        rule-id   = "3"
        rule-name = "map-financial-to-topic"
        object-locator = {
          schema-name = "public"
          table-name  = var.FINANCIAL_TRANSACTIONS_TABLE_NAME
        }
        rule-action        = "map-record-to-record"
        kafka-target-topic = data.aws_ssm_parameter.msk_aurora_financial_transactions_topic.value
      },
      {
        rule-type = "object-mapping"
        rule-id   = "4"
        rule-name = "map-brokerage-to-topic"
        object-locator = {
          schema-name = "public"
          table-name  = var.BROKERAGE_TRANSACTIONS_TABLE_NAME
        }
        rule-action        = "map-record-to-record"
        kafka-target-topic = data.aws_ssm_parameter.msk_aurora_brokerage_transactions_topic.value
      }
    ]
  })
}

# DMS Module for Aurora
module "aurora_dms" {
  source = "../../../templates/modules/dms"

  APP = var.APP
  ENV = var.ENV

  dms_kms_key_alias              = var.DMS_KMS_KEY_ALIAS
  dms_replication_instance_class = var.DMS_REPLICATION_INSTANCE_CLASS
  dms_allocated_storage          = var.DMS_ALLOCATED_STORAGE
  dms_engine_version             = var.DMS_ENGINE_VERSION
  dms_multi_az                   = var.DMS_MULTI_AZ
  dms_publicly_accessible        = var.DMS_PUBLICLY_ACCESSIBLE
  dms_auto_minor_version_upgrade = var.DMS_AUTO_MINOR_VERSION_UPGRADE
  dms_apply_immediately          = var.DMS_APPLY_IMMEDIATELY

  source_engine = "aurora-postgresql"

  source_endpoint_config = {
    server_name                 = local.aurora_endpoint
    port                        = local.aurora_port
    database_name               = local.aurora_database
    username                    = local.aurora_credentials.username
    password                    = local.aurora_credentials.password
    ssl_mode                    = "require"
    extra_connection_attributes = "heartbeatEnable=true;heartbeatFrequency=30;heartbeatSchema=public"
  }

  msk_message_format = var.MSK_MESSAGE_FORMAT

  table_mappings              = local.aurora_table_mappings
  migration_type              = var.AURORA_MSK_MIGRATION_TYPE
  start_replication_task      = var.START_AURORA_REPLICATION_TASK
  replication_task_settings   = var.DMS_MSK_REPLICATION_TASK_SETTINGS
  replication_instance_suffix = "aurora"
}
