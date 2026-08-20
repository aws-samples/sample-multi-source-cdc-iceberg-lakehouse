# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

APP    = "###APP_NAME###"
ENV    = "###ENV_NAME###"
REGION = "###AWS_PRIMARY_REGION###"

# MSK SASL/SCRAM Authentication (required for DMS integration)
ENABLE_MSK_SASL_AUTH = true
MSK_CLUSTER_NAME     = "msk-ingest-cluster"

# DMS topics (Path 1: DMS/Changefeed -> Firehose -> S3 Iceberg)
ORACLE_FINANCIAL_TRANSACTIONS_TOPIC_NAME    = "dms_oracle_fin"
ORACLE_BROKERAGE_TRANSACTIONS_TOPIC_NAME    = "dms_oracle_brk"
AURORA_FINANCIAL_TRANSACTIONS_TOPIC_NAME    = "dms_aurora_fin"
AURORA_BROKERAGE_TRANSACTIONS_TOPIC_NAME    = "dms_aurora_brk"
COCKROACH_FINANCIAL_TRANSACTIONS_TOPIC_NAME = "crdb_fin"
COCKROACH_BROKERAGE_TRANSACTIONS_TOPIC_NAME = "crdb_brk"

# Debezium topics (Path 2: Debezium -> Apache Flink -> Iceberg)
CONNECT_ORACLE_FINANCIAL_TRANSACTIONS_TOPIC_NAME = "###APP_NAME###_###ENV_NAME###_dbz_oracle_fin"
CONNECT_ORACLE_BROKERAGE_TRANSACTIONS_TOPIC_NAME = "###APP_NAME###_###ENV_NAME###_dbz_oracle_brk"
CONNECT_AURORA_FINANCIAL_TRANSACTIONS_TOPIC_NAME = "###APP_NAME###_###ENV_NAME###_dbz_aurora_fin"
CONNECT_AURORA_BROKERAGE_TRANSACTIONS_TOPIC_NAME = "###APP_NAME###_###ENV_NAME###_dbz_aurora_brk"

KAFKA_VERSION       = "3.9.x"
KAFKA_INSTANCE_TYPE = "kafka.m5.large"
KAFKA_STORAGE_SIZE  = 1000

KAFKA_CLIENT_VERSION = "3.9.1"
