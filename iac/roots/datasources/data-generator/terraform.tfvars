# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

APP    = "###APP_NAME###"
ENV    = "###ENV_NAME###"
REGION = "###AWS_PRIMARY_REGION###"

ENABLE_MSK_INTEGRATION       = true
ENABLE_AURORA_INTEGRATION    = true
ENABLE_COCKROACH_INTEGRATION = true
ENABLE_ORACLE_INTEGRATION    = true

# Oracle tables
ORACLE_FINANCIAL_TRANSACTIONS_TABLE_NAME = "financial_transactions"
ORACLE_BROKERAGE_TRANSACTIONS_TABLE_NAME = "brokerage_transactions"

# Cockroach tables
COCKROACH_FINANCIAL_TRANSACTIONS_TABLE_NAME = "financial_transactions"
COCKROACH_BROKERAGE_TRANSACTIONS_TABLE_NAME = "brokerage_transactions"

# Aurora tables
AURORA_FINANCIAL_TRANSACTIONS_TABLE_NAME = "financial_transactions"
AURORA_BROKERAGE_TRANSACTIONS_TABLE_NAME = "brokerage_transactions"

# MSK Source topic names
MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME_PARAMETER = "topic-msk-src-fin"
MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME_PARAMETER = "topic-msk-src-brk"
