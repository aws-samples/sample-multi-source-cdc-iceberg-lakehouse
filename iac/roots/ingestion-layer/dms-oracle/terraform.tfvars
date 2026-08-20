# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Application Configuration
APP                = "###APP_NAME###"
ENV                = "###ENV_NAME###"
AWS_PRIMARY_REGION = "###AWS_PRIMARY_REGION###"
DMS_KMS_KEY_ALIAS  = "###APP_NAME###-###ENV_NAME###-dms-secret-key"

# DMS Configuration - Optimized for CDC performance
DMS_REPLICATION_INSTANCE_CLASS = "dms.r5.4xlarge"
DMS_ALLOCATED_STORAGE          = 200
DMS_ENGINE_VERSION             = "3.6.1"
DMS_MULTI_AZ                   = false
DMS_PUBLICLY_ACCESSIBLE        = false
DMS_AUTO_MINOR_VERSION_UPGRADE = true
DMS_APPLY_IMMEDIATELY          = false
MSK_MESSAGE_FORMAT             = "json"

# Oracle Source Configuration
ORACLE_MSK_MIGRATION_TYPE             = "cdc"
START_ORACLE_REPLICATION_TASK         = false
FINANCIAL_TRANSACTIONS_TABLE_NAME     = "financial_transactions"
BROKERAGE_TRANSACTIONS_TABLE_NAME     = "brokerage_transactions"
ORACLE_FINANCIAL_TOPIC_NAME_PARAMETER = "topic-dms-oracle-fin"
ORACLE_BROKERAGE_TOPIC_NAME_PARAMETER = "topic-dms-oracle-brk"
