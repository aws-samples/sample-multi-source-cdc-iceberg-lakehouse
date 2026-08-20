# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Source Endpoint
resource "aws_dms_endpoint" "source" {
  #checkov:skip=CKV_AWS_296:DMS endpoint encryption not required for this sample
  #checkov:skip=CKV2_AWS_49:SSL not configured — source databases are in the same private VPC as DMS
  endpoint_id   = "${var.APP}-${var.ENV}-${var.replication_instance_suffix}-source"
  endpoint_type = "source"
  engine_name   = var.source_engine

  server_name   = var.source_endpoint_config.server_name
  port          = var.source_endpoint_config.port
  database_name = var.source_endpoint_config.database_name
  username      = var.source_endpoint_config.username
  password      = var.source_endpoint_config.password

  kms_key_arn = data.aws_kms_key.dms_kms_key.arn
  ssl_mode    = var.source_endpoint_config.ssl_mode

  extra_connection_attributes = var.source_endpoint_config.extra_connection_attributes

  tags = merge(local.tags, {
    Name = "${var.APP}-${var.ENV}-${var.replication_instance_suffix}-source-endpoint"
  })
}

# MSK Target Endpoint
resource "aws_dms_endpoint" "msk_target" {
  #checkov:skip=CKV_AWS_296:DMS endpoint encryption not required for this sample
  endpoint_id   = "${var.APP}-${var.ENV}-${var.replication_instance_suffix}-msk-target"
  endpoint_type = "target"
  engine_name   = "kafka"

  # Kafka configuration for SASL/SCRAM authentication
  kafka_settings {
    broker                         = local.sasl_scram_broker_list
    message_format                 = var.msk_message_format
    include_transaction_details    = false # Disable DMS transaction metadata
    include_partition_value        = false # Disable partition metadata
    partition_include_schema_table = false # Disable schema/table in partition key
    include_table_alter_operations = false # Disable DDL operation metadata
    include_control_details        = false # Disable DMS control metadata
    message_max_bytes              = 1000000
    include_null_and_empty         = true

    # Use SASL-SSL for SASL/SCRAM authentication with MSK
    security_protocol = "sasl-ssl"
    sasl_username     = local.msk_credentials.username
    sasl_password     = local.msk_credentials.password

    no_hex_prefix = false
  }

  tags = merge(local.tags, {
    Name = "${var.APP}-${var.ENV}-${var.replication_instance_suffix}-msk-target-endpoint"
  })
}
