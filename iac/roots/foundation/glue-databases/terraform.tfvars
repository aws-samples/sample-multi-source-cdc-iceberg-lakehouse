# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

APP                = "###APP_NAME###"
ENV                = "###ENV_NAME###"
AWS_PRIMARY_REGION = "###AWS_PRIMARY_REGION###"

# Firehose databases (Path 1)
ORACLE_TRANSACTIONS_DATABASE_NAME    = "f_oracle"
AURORA_TRANSACTIONS_DATABASE_NAME    = "f_aurora"
COCKROACH_TRANSACTIONS_DATABASE_NAME = "f_crdb"
MSK_TRANSACTIONS_DATABASE_NAME       = "f_msk_src"

# Connect databases (Path 2)
CONNECT_ORACLE_TRANSACTIONS_DATABASE_NAME    = "c_oracle"
CONNECT_AURORA_TRANSACTIONS_DATABASE_NAME    = "c_aurora"
CONNECT_COCKROACH_TRANSACTIONS_DATABASE_NAME = "c_crdb"
CONNECT_MSK_TRANSACTIONS_DATABASE_NAME       = "c_msk_src"
