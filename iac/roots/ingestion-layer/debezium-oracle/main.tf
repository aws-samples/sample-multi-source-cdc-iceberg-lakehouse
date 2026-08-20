# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"
}

# -----------------------------------------------------------------------------
# Debezium Oracle Source Connector via MSK Connect (Path 2)
#
# Reads CDC events from Oracle using LogMiner (online_catalog strategy),
# unwraps the Debezium envelope via ExtractNewRecordState SMT, and routes
# financial/brokerage tables to existing MSK Ingest topic names via
# ByLogicalTableRouter SMT — matching the same topic names used by DMS (Path 1).
# -----------------------------------------------------------------------------

module "debezium_oracle" {
  source = "../../../templates/modules/msk-connect-debezium-source"

  APP            = var.APP
  ENV            = var.ENV
  CONNECTOR_NAME = "oracle"

  MSK_BOOTSTRAP_SERVERS  = local.msk_bootstrap_servers
  VPC_SUBNET_IDS         = local.private_subnet_ids
  VPC_SECURITY_GROUP_IDS = [local.vpc_sg]
  EXECUTION_ROLE_ARN     = local.execution_role_arn

  PLUGIN_S3_BUCKET_ARN = local.plugins_bucket_arn
  PLUGIN_S3_KEY        = var.DEBEZIUM_ORACLE_PLUGIN_S3_KEY

  KAFKACONNECT_VERSION     = var.KAFKACONNECT_VERSION
  USE_PROVISIONED_CAPACITY = var.USE_PROVISIONED_CAPACITY
  WORKER_COUNT             = var.WORKER_COUNT
  MCU_COUNT                = var.MCU_COUNT

  CONNECTOR_CONFIG = {
    # Connector class
    "connector.class" = "io.debezium.connector.oracle.OracleConnector"
    "tasks.max"       = "1"

    # Oracle connection — connect to CDB root for LogMiner access, specify PDB for filtering
    "database.hostname"    = local.oracle_host
    "database.port"        = local.oracle_port
    "database.user"        = "C##DBZUSER"
    "database.password"    = data.aws_secretsmanager_secret_version.oracle_cdc_password.secret_string
    "database.dbname"      = local.oracle_sid
    "database.pdb.name"    = local.oracle_pdb
    "database.url"         = "jdbc:oracle:thin:@//${local.oracle_host}:${local.oracle_port}/${local.oracle_sid}"
    "database.server.name" = "${var.APP}_${var.ENV}_oracle"
    "topic.prefix"         = "${var.APP}_${var.ENV}_oracle"

    # Type mapping — normalize Oracle-specific types for cross-source consistency
    "time.precision.mode" = "connect"
    "converters"          = "boolean"
    "boolean.type"        = "io.debezium.connector.oracle.converters.NumberOneToBooleanConverter"
    "boolean.selector"    = ".*"

    # LogMiner CDC configuration
    "schema.history.internal.kafka.bootstrap.servers" = local.msk_bootstrap_servers
    "schema.history.internal.kafka.topic"             = "__debezium_oracle_schema_history"
    "log.mining.strategy"                             = "online_catalog"
    "log.mining.continuous.mine"                      = "false"
    "log.mining.archive.log.only.mode"                = "false"
    "log.mining.sleep.time.default.ms"                = "1000"
    "log.mining.sleep.time.min.ms"                    = "0"
    "log.mining.sleep.time.max.ms"                    = "3000"
    "log.mining.batch.size.default"                   = "20000"
    "log.mining.batch.size.min"                       = "1000"
    "log.mining.batch.size.max"                       = "100000"

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

    # Table selection — replicate financial and brokerage tables
    "table.include.list" = "${upper(local.oracle_user)}.${upper(var.FINANCIAL_TRANSACTIONS_TABLE_NAME)},${upper(local.oracle_user)}.${upper(var.BROKERAGE_TRANSACTIONS_TABLE_NAME)}"

    # Snapshot mode — schema_only for CDC-only (no initial full load)
    "snapshot.mode" = "schema_only"

    # Heartbeat to keep connector alive during low-activity periods
    "heartbeat.interval.ms" = "0"

    # Transforms: unwrap Debezium envelope + route to existing topic names
    "transforms"                                  = "unwrap,routeFinancial,routeBrokerage"
    "transforms.unwrap.type"                      = "io.debezium.transforms.ExtractNewRecordState"
    "transforms.unwrap.delete.handling.mode"      = "rewrite"
    "transforms.unwrap.drop.tombstones"           = "true"
    "transforms.unwrap.add.fields"                = "op,source.ts_ms"
    "transforms.routeFinancial.type"              = "io.debezium.transforms.ByLogicalTableRouter"
    "transforms.routeFinancial.topic.regex"       = ".*${upper(var.FINANCIAL_TRANSACTIONS_TABLE_NAME)}$$"
    "transforms.routeFinancial.topic.replacement" = local.financial_topic
    "transforms.routeBrokerage.type"              = "io.debezium.transforms.ByLogicalTableRouter"
    "transforms.routeBrokerage.topic.regex"       = ".*${upper(var.BROKERAGE_TRANSACTIONS_TABLE_NAME)}$$"
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
    "errors.deadletterqueue.topic.name"             = "__debezium_oracle_dlq"
    "errors.deadletterqueue.context.headers.enable" = "true"
  }
}
