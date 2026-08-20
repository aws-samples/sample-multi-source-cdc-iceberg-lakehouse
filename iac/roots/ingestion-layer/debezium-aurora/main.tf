# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"
}

# -----------------------------------------------------------------------------
# Debezium Aurora/PostgreSQL Source Connector via MSK Connect (Path 2)
#
# Reads CDC events from Aurora PostgreSQL using pgoutput logical decoding,
# unwraps the Debezium envelope via ExtractNewRecordState SMT, and routes
# financial/brokerage tables to existing MSK Ingest topic names via
# ByLogicalTableRouter SMT — matching the same topic names used by DMS (Path 1).
# -----------------------------------------------------------------------------

module "debezium_aurora" {
  source = "../../../templates/modules/msk-connect-debezium-source"

  APP            = var.APP
  ENV            = var.ENV
  CONNECTOR_NAME = "aurora"

  MSK_BOOTSTRAP_SERVERS  = local.msk_bootstrap_servers
  VPC_SUBNET_IDS         = local.private_subnet_ids
  VPC_SECURITY_GROUP_IDS = [local.vpc_sg]
  EXECUTION_ROLE_ARN     = local.execution_role_arn

  PLUGIN_S3_BUCKET_ARN = local.plugins_bucket_arn
  PLUGIN_S3_KEY        = var.DEBEZIUM_POSTGRES_PLUGIN_S3_KEY

  KAFKACONNECT_VERSION = var.KAFKACONNECT_VERSION
  MIN_WORKERS          = var.MIN_WORKERS
  MAX_WORKERS          = var.MAX_WORKERS
  MCU_COUNT            = var.MCU_COUNT

  CONNECTOR_CONFIG = {
    # Connector class
    "connector.class" = "io.debezium.connector.postgresql.PostgresConnector"
    "tasks.max"       = "1"

    # Aurora PostgreSQL connection
    "database.hostname"    = local.aurora_endpoint
    "database.port"        = local.aurora_port
    "database.user"        = local.aurora_credentials.username
    "database.password"    = local.aurora_credentials.password
    "database.dbname"      = local.aurora_database
    "database.server.name" = "${var.APP}_${var.ENV}_aurora"
    "topic.prefix"         = "${var.APP}_${var.ENV}_aurora"

    # Type mapping — use Kafka Connect native temporal types for cross-catalog consistency
    "time.precision.mode" = "connect"

    # Logical decoding configuration
    "plugin.name"      = "pgoutput"
    "slot.name"        = "debezium_aurora"
    "publication.name" = "debezium_aurora_pub"

    # Schema history
    "schema.history.internal.kafka.bootstrap.servers" = local.msk_bootstrap_servers
    "schema.history.internal.kafka.topic"             = "__debezium_aurora_schema_history"

    # Schema history internal Kafka client IAM auth — required because Debezium's
    # schema history producer/consumer create their own Kafka clients that don't
    # inherit MSK Connect's platform-level IAM auth injection.
    "schema.history.internal.consumer.security.protocol"                  = "SASL_SSL"
    "schema.history.internal.consumer.sasl.mechanism"                     = "AWS_MSK_IAM"
    "schema.history.internal.consumer.sasl.jaas.config"                   = "software.amazon.msk.auth.iam.IAMLoginModule required;"
    "schema.history.internal.consumer.sasl.client.callback.handler.class" = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"
    "schema.history.internal.producer.security.protocol"                  = "SASL_SSL"
    "schema.history.internal.producer.sasl.mechanism"                     = "AWS_MSK_IAM"
    "schema.history.internal.producer.sasl.jaas.config"                   = "software.amazon.msk.auth.iam.IAMLoginModule required;"
    "schema.history.internal.producer.sasl.client.callback.handler.class" = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"

    # Table selection — replicate financial and brokerage tables from public schema
    "table.include.list" = "public.${var.FINANCIAL_TRANSACTIONS_TABLE_NAME},public.${var.BROKERAGE_TRANSACTIONS_TABLE_NAME}"

    # Snapshot mode — schema_only for CDC-only (no initial full load)
    "snapshot.mode" = "never"

    # Heartbeat to keep connector alive during low-activity periods
    "heartbeat.interval.ms" = "0"

    # Transforms: unwrap Debezium envelope + route to existing topic names
    "transforms"                                  = "unwrap,routeFinancial,routeBrokerage"
    "transforms.unwrap.type"                      = "io.debezium.transforms.ExtractNewRecordState"
    "transforms.unwrap.delete.handling.mode"      = "rewrite"
    "transforms.unwrap.drop.tombstones"           = "true"
    "transforms.unwrap.add.fields"                = "op,source.ts_ms"
    "transforms.routeFinancial.type"              = "io.debezium.transforms.ByLogicalTableRouter"
    "transforms.routeFinancial.topic.regex"       = ".*${var.FINANCIAL_TRANSACTIONS_TABLE_NAME}$$"
    "transforms.routeFinancial.topic.replacement" = local.financial_topic
    "transforms.routeBrokerage.type"              = "io.debezium.transforms.ByLogicalTableRouter"
    "transforms.routeBrokerage.topic.regex"       = ".*${var.BROKERAGE_TRANSACTIONS_TABLE_NAME}$$"
    "transforms.routeBrokerage.topic.replacement" = local.brokerage_topic

    # Converter settings — JSON (Flink jobs consume JSON from MSK)
    "key.converter"                  = "org.apache.kafka.connect.json.JsonConverter"
    "key.converter.schemas.enable"   = "false"
    "value.converter"                = "org.apache.kafka.connect.json.JsonConverter"
    "value.converter.schemas.enable" = "false"

    # Disable schema change topic — Debezium's DDL tracking topic (named after
    # topic.prefix) causes Glue Schema Registry FAILURE versions due to BACKWARD
    # compatibility on the auto-created schema. Not needed for the CDC data flow.
    "include.schema.changes" = "false"

    # Error handling
    "errors.tolerance"                              = "none"
    "errors.log.enable"                             = "true"
    "errors.log.include.messages"                   = "true"
    "errors.deadletterqueue.topic.name"             = "__debezium_aurora_dlq"
    "errors.deadletterqueue.context.headers.enable" = "true"
  }
}
