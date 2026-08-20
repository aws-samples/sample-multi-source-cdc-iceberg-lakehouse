# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

# =============================================================================
# Explicit Glue Iceberg tables for Connect databases (Path 2)
# Pre-created at foundation deploy time. Each module depends on the
# corresponding LF permission so that during destroy, tables are dropped
# BEFORE the IAM_ALLOWED_PRINCIPALS grant is revoked.
# =============================================================================

locals {
  iceberg_s3_bucket = "${var.APP}-${var.ENV}-iceberg-datalake-primary"
}

data "aws_kms_key" "ssm_kms_key" {
  key_id = "alias/${var.APP}-${var.ENV}-systems-manager-secret-key"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

terraform {
  required_version = ">= 1.8.0"
}

# Oracle Transactions Database
resource "aws_glue_catalog_database" "oracle_transactions_database" {
  name = "${var.APP}_${var.ENV}_${var.ORACLE_TRANSACTIONS_DATABASE_NAME}"

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "oracle-glue-database"
  }
}

# Aurora Transactions Database
resource "aws_glue_catalog_database" "aurora_transactions_database" {
  name = "${var.APP}_${var.ENV}_${var.AURORA_TRANSACTIONS_DATABASE_NAME}"

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "aurora-glue-database"
  }
}

# Cockroach Transactions Database
resource "aws_glue_catalog_database" "cockroach_transactions_database" {
  name = "${var.APP}_${var.ENV}_${var.COCKROACH_TRANSACTIONS_DATABASE_NAME}"

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "cockroach-glue-database"
  }
}

# MSK Transactions Database
resource "aws_glue_catalog_database" "msk_transactions_database" {
  name = "${var.APP}_${var.ENV}_${var.MSK_TRANSACTIONS_DATABASE_NAME}"

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "msk-glue-database"
  }
}

# Connect Oracle Transactions Database
resource "aws_glue_catalog_database" "connect_oracle_transactions_database" {
  name = "${var.APP}_${var.ENV}_${var.CONNECT_ORACLE_TRANSACTIONS_DATABASE_NAME}"

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "connect-oracle-glue-database"
  }
}

# Connect Aurora Transactions Database
resource "aws_glue_catalog_database" "connect_aurora_transactions_database" {
  name = "${var.APP}_${var.ENV}_${var.CONNECT_AURORA_TRANSACTIONS_DATABASE_NAME}"

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "connect-aurora-glue-database"
  }
}

# Connect Cockroach Transactions Database
resource "aws_glue_catalog_database" "connect_cockroach_transactions_database" {
  name = "${var.APP}_${var.ENV}_${var.CONNECT_COCKROACH_TRANSACTIONS_DATABASE_NAME}"

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "connect-cockroach-glue-database"
  }
}

# Connect MSK Transactions Database
resource "aws_glue_catalog_database" "connect_msk_transactions_database" {
  name = "${var.APP}_${var.ENV}_${var.CONNECT_MSK_TRANSACTIONS_DATABASE_NAME}"

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "connect-msk-glue-database"
  }
}

# SSM Parameters for database names
resource "aws_ssm_parameter" "oracle_transactions_database_name" {
  name   = "/${var.APP}/${var.ENV}/db-f-oracle"
  type   = "SecureString"
  value  = aws_glue_catalog_database.oracle_transactions_database.name
  key_id = data.aws_kms_key.ssm_kms_key.arn

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "ssm-parameter"
  }
}

resource "aws_ssm_parameter" "aurora_transactions_database_name" {
  name   = "/${var.APP}/${var.ENV}/db-f-aurora"
  type   = "SecureString"
  value  = aws_glue_catalog_database.aurora_transactions_database.name
  key_id = data.aws_kms_key.ssm_kms_key.arn

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "ssm-parameter"
  }
}

resource "aws_ssm_parameter" "cockroach_transactions_database_name" {
  name   = "/${var.APP}/${var.ENV}/db-f-crdb"
  type   = "SecureString"
  value  = aws_glue_catalog_database.cockroach_transactions_database.name
  key_id = data.aws_kms_key.ssm_kms_key.arn

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "ssm-parameter"
  }
}

resource "aws_ssm_parameter" "msk_transactions_database_name" {
  name   = "/${var.APP}/${var.ENV}/db-f-msk-src"
  type   = "SecureString"
  value  = aws_glue_catalog_database.msk_transactions_database.name
  key_id = data.aws_kms_key.ssm_kms_key.arn

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "ssm-parameter"
  }
}

resource "aws_ssm_parameter" "connect_oracle_transactions_database_name" {
  name   = "/${var.APP}/${var.ENV}/db-c-oracle"
  type   = "SecureString"
  value  = aws_glue_catalog_database.connect_oracle_transactions_database.name
  key_id = data.aws_kms_key.ssm_kms_key.arn

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "ssm-parameter"
  }
}

resource "aws_ssm_parameter" "connect_aurora_transactions_database_name" {
  name   = "/${var.APP}/${var.ENV}/db-c-aurora"
  type   = "SecureString"
  value  = aws_glue_catalog_database.connect_aurora_transactions_database.name
  key_id = data.aws_kms_key.ssm_kms_key.arn

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "ssm-parameter"
  }
}

resource "aws_ssm_parameter" "connect_cockroach_transactions_database_name" {
  name   = "/${var.APP}/${var.ENV}/db-c-crdb"
  type   = "SecureString"
  value  = aws_glue_catalog_database.connect_cockroach_transactions_database.name
  key_id = data.aws_kms_key.ssm_kms_key.arn

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "ssm-parameter"
  }
}

resource "aws_ssm_parameter" "connect_msk_transactions_database_name" {
  name   = "/${var.APP}/${var.ENV}/db-c-msk-src"
  type   = "SecureString"
  value  = aws_glue_catalog_database.connect_msk_transactions_database.name
  key_id = data.aws_kms_key.ssm_kms_key.arn

  tags = {
    App         = var.APP
    Environment = var.ENV
    Component   = "ssm-parameter"
  }
}

# =============================================================================
# Lake Formation permissions for Connect databases (Path 2)
#
# The Path 2 Flink apps run as their IAM role and modify Glue
# table metadata on every Iceberg commit (UpdateTable). Without explicit grants,
# Lake Formation assigns ownership to that role, and the Admin role
# cannot DROP tables during terraform destroy.
#
# Granting IAM_ALLOWED_PRINCIPALS on these databases/tables opts them out of
# LF permission enforcement, allowing any IAM principal with Glue permissions
# (including Admin) to manage them.
# =============================================================================

resource "aws_lakeformation_permissions" "connect_oracle_db_iam" {
  principal   = "IAM_ALLOWED_PRINCIPALS"
  permissions = ["ALL"]

  database {
    name = aws_glue_catalog_database.connect_oracle_transactions_database.name
  }
}

resource "aws_lakeformation_permissions" "connect_aurora_db_iam" {
  principal   = "IAM_ALLOWED_PRINCIPALS"
  permissions = ["ALL"]

  database {
    name = aws_glue_catalog_database.connect_aurora_transactions_database.name
  }
}

resource "aws_lakeformation_permissions" "connect_cockroach_db_iam" {
  principal   = "IAM_ALLOWED_PRINCIPALS"
  permissions = ["ALL"]

  database {
    name = aws_glue_catalog_database.connect_cockroach_transactions_database.name
  }
}

resource "aws_lakeformation_permissions" "connect_msk_db_iam" {
  principal   = "IAM_ALLOWED_PRINCIPALS"
  permissions = ["ALL"]

  database {
    name = aws_glue_catalog_database.connect_msk_transactions_database.name
  }
}

# =============================================================================
# Lake Formation permissions for Firehose databases (Path 1)
#
# Same pattern as Connect databases — grant IAM_ALLOWED_PRINCIPALS so that
# any IAM principal with Glue permissions can see tables in the Athena console.
# =============================================================================

resource "aws_lakeformation_permissions" "firehose_oracle_db_iam" {
  principal   = "IAM_ALLOWED_PRINCIPALS"
  permissions = ["ALL"]

  database {
    name = aws_glue_catalog_database.oracle_transactions_database.name
  }
}

resource "aws_lakeformation_permissions" "firehose_aurora_db_iam" {
  principal   = "IAM_ALLOWED_PRINCIPALS"
  permissions = ["ALL"]

  database {
    name = aws_glue_catalog_database.aurora_transactions_database.name
  }
}

resource "aws_lakeformation_permissions" "firehose_cockroach_db_iam" {
  principal   = "IAM_ALLOWED_PRINCIPALS"
  permissions = ["ALL"]

  database {
    name = aws_glue_catalog_database.cockroach_transactions_database.name
  }
}

resource "aws_lakeformation_permissions" "firehose_msk_db_iam" {
  principal   = "IAM_ALLOWED_PRINCIPALS"
  permissions = ["ALL"]

  database {
    name = aws_glue_catalog_database.msk_transactions_database.name
  }
}

# Oracle Connect — financial
module "connect_oracle_financial_table" {
  source = "../../../templates/modules/glue-transactions-table"

  APP               = var.APP
  ENV               = var.ENV
  DATABASE_NAME     = aws_glue_catalog_database.connect_oracle_transactions_database.name
  S3_BUCKET_NAME    = local.iceberg_s3_bucket
  TABLE_NAME        = "fin"
  TABLE_TYPE        = "financial"
  UPPERCASE_COLUMNS = true

  depends_on = [aws_lakeformation_permissions.connect_oracle_db_iam]
}

# Oracle Connect — brokerage
module "connect_oracle_brokerage_table" {
  source = "../../../templates/modules/glue-transactions-table"

  APP               = var.APP
  ENV               = var.ENV
  DATABASE_NAME     = aws_glue_catalog_database.connect_oracle_transactions_database.name
  S3_BUCKET_NAME    = local.iceberg_s3_bucket
  TABLE_NAME        = "brk"
  TABLE_TYPE        = "brokerage"
  UPPERCASE_COLUMNS = true

  depends_on = [aws_lakeformation_permissions.connect_oracle_db_iam]
}

# Aurora Connect — financial
module "connect_aurora_financial_table" {
  source = "../../../templates/modules/glue-transactions-table"

  APP            = var.APP
  ENV            = var.ENV
  DATABASE_NAME  = aws_glue_catalog_database.connect_aurora_transactions_database.name
  S3_BUCKET_NAME = local.iceberg_s3_bucket
  TABLE_NAME     = "fin"
  TABLE_TYPE     = "financial"

  depends_on = [aws_lakeformation_permissions.connect_aurora_db_iam]
}

# Aurora Connect — brokerage
module "connect_aurora_brokerage_table" {
  source = "../../../templates/modules/glue-transactions-table"

  APP            = var.APP
  ENV            = var.ENV
  DATABASE_NAME  = aws_glue_catalog_database.connect_aurora_transactions_database.name
  S3_BUCKET_NAME = local.iceberg_s3_bucket
  TABLE_NAME     = "brk"
  TABLE_TYPE     = "brokerage"

  depends_on = [aws_lakeformation_permissions.connect_aurora_db_iam]
}

# Cockroach Connect — financial
module "connect_cockroach_financial_table" {
  source = "../../../templates/modules/glue-transactions-table"

  APP            = var.APP
  ENV            = var.ENV
  DATABASE_NAME  = aws_glue_catalog_database.connect_cockroach_transactions_database.name
  S3_BUCKET_NAME = local.iceberg_s3_bucket
  TABLE_NAME     = "fin"
  TABLE_TYPE     = "financial"

  depends_on = [aws_lakeformation_permissions.connect_cockroach_db_iam]
}

# Cockroach Connect — brokerage
module "connect_cockroach_brokerage_table" {
  source = "../../../templates/modules/glue-transactions-table"

  APP            = var.APP
  ENV            = var.ENV
  DATABASE_NAME  = aws_glue_catalog_database.connect_cockroach_transactions_database.name
  S3_BUCKET_NAME = local.iceberg_s3_bucket
  TABLE_NAME     = "brk"
  TABLE_TYPE     = "brokerage"

  depends_on = [aws_lakeformation_permissions.connect_cockroach_db_iam]
}

# MSK Source Connect — financial
module "connect_msk_financial_table" {
  source = "../../../templates/modules/glue-transactions-table"

  APP            = var.APP
  ENV            = var.ENV
  DATABASE_NAME  = aws_glue_catalog_database.connect_msk_transactions_database.name
  S3_BUCKET_NAME = local.iceberg_s3_bucket
  TABLE_NAME     = "fin"
  TABLE_TYPE     = "financial"

  depends_on = [aws_lakeformation_permissions.connect_msk_db_iam]
}

# MSK Source Connect — brokerage
module "connect_msk_brokerage_table" {
  source = "../../../templates/modules/glue-transactions-table"

  APP            = var.APP
  ENV            = var.ENV
  DATABASE_NAME  = aws_glue_catalog_database.connect_msk_transactions_database.name
  S3_BUCKET_NAME = local.iceberg_s3_bucket
  TABLE_NAME     = "brk"
  TABLE_TYPE     = "brokerage"

  depends_on = [aws_lakeformation_permissions.connect_msk_db_iam]
}
