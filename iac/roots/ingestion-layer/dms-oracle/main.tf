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

# Get Oracle connection details from SSM Parameter Store
data "aws_ssm_parameter" "oracle_user" {
  name = "/${var.APP}/${var.ENV}/oracle-user"
}

data "aws_ssm_parameter" "oracle_host" {
  name = "/${var.APP}/${var.ENV}/oracle-host"
}

data "aws_ssm_parameter" "oracle_port" {
  name = "/${var.APP}/${var.ENV}/oracle-port"
}

data "aws_ssm_parameter" "oracle_sid" {
  name = "/${var.APP}/${var.ENV}/oracle-sid"
}

data "aws_ssm_parameter" "oracle_pdb" {
  name = "/${var.APP}/${var.ENV}/oracle-pdb"
}

data "aws_ssm_parameter" "msk_oracle_financial_transactions_topic" {
  name = "/${var.APP}/${var.ENV}/${var.ORACLE_FINANCIAL_TOPIC_NAME_PARAMETER}"
}

data "aws_ssm_parameter" "msk_oracle_brokerage_transactions_topic" {
  name = "/${var.APP}/${var.ENV}/${var.ORACLE_BROKERAGE_TOPIC_NAME_PARAMETER}"
}

# Get Oracle admin password from Secrets Manager
data "aws_secretsmanager_secret" "oracle_cdc_password" {
  name = "${var.APP}-${var.ENV}-oracle-cdc-password"
}

data "aws_secretsmanager_secret_version" "oracle_cdc_password" {
  secret_id = data.aws_secretsmanager_secret.oracle_cdc_password.id
}

locals {
  oracle_user = data.aws_ssm_parameter.oracle_user.value

  # Combined DMS table mappings for Oracle - Routes both transaction types to respective topics
  oracle_table_mappings = jsonencode({
    rules = [
      # Selection rules - specify which tables to replicate
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "select-financial-table"
        object-locator = {
          schema-name = upper(local.oracle_user)
          table-name  = upper(var.FINANCIAL_TRANSACTIONS_TABLE_NAME)
        }
        rule-action = "include"
      },
      {
        rule-type = "selection"
        rule-id   = "2"
        rule-name = "select-brokerage-table"
        object-locator = {
          schema-name = upper(local.oracle_user)
          table-name  = upper(var.BROKERAGE_TRANSACTIONS_TABLE_NAME)
        }
        rule-action = "include"
      },
      # Object mapping rules - route tables to specific Kafka topics
      {
        rule-type = "object-mapping"
        rule-id   = "3"
        rule-name = "map-financial-to-topic"
        object-locator = {
          schema-name = upper(local.oracle_user)
          table-name  = upper(var.FINANCIAL_TRANSACTIONS_TABLE_NAME)
        }
        rule-action        = "map-record-to-record"
        kafka-target-topic = data.aws_ssm_parameter.msk_oracle_financial_transactions_topic.value
      },
      {
        rule-type = "object-mapping"
        rule-id   = "4"
        rule-name = "map-brokerage-to-topic"
        object-locator = {
          schema-name = upper(local.oracle_user)
          table-name  = upper(var.BROKERAGE_TRANSACTIONS_TABLE_NAME)
        }
        rule-action        = "map-record-to-record"
        kafka-target-topic = data.aws_ssm_parameter.msk_oracle_brokerage_transactions_topic.value
      }
    ]
  })
}

# DMS Module for Oracle
module "oracle_dms" {
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

  source_engine = "oracle"

  source_endpoint_config = {
    server_name                 = data.aws_ssm_parameter.oracle_host.value
    port                        = tonumber(data.aws_ssm_parameter.oracle_port.value)
    database_name               = data.aws_ssm_parameter.oracle_pdb.value
    username                    = "C##DMSUSER"
    password                    = data.aws_secretsmanager_secret_version.oracle_cdc_password.secret_string
    ssl_mode                    = "none"
    extra_connection_attributes = "useLogminerReader=N;useBfile=Y;addSupplementalLogging=N"
  }

  msk_message_format = var.MSK_MESSAGE_FORMAT

  table_mappings              = local.oracle_table_mappings
  migration_type              = var.ORACLE_MSK_MIGRATION_TYPE
  start_replication_task      = var.START_ORACLE_REPLICATION_TASK
  replication_task_settings   = var.DMS_MSK_REPLICATION_TASK_SETTINGS
  replication_instance_suffix = "oracle"
}
