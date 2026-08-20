# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  tags = {
    Application = var.APP
    Environment = var.ENV
    Component   = "s3-tables"
  }

  # Shared maintenance configuration for all tables
  table_maintenance = {
    iceberg_compaction = {
      status = "enabled"
      settings = {
        target_file_size_mb = 256
      }
    }
    iceberg_snapshot_management = {
      status = "enabled"
      settings = {
        max_snapshot_age_hours = 24
        min_snapshots_to_keep  = 3
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Iceberg schema definitions (maps Glue types → Iceberg primitive types)
  # Glue bigint → Iceberg long, Glue int → Iceberg int, rest map 1:1
  # ---------------------------------------------------------------------------

  financial_schema = [
    { name = "transaction_id", type = "string", required = true },
    { name = "transaction_reference_id", type = "string", required = false },
    { name = "transaction_type", type = "string", required = false },
    { name = "transaction_subtype", type = "string", required = false },
    { name = "timestamp", type = "timestamp", required = false },
    { name = "transaction_date", type = "date", required = false },
    { name = "transaction_time", type = "string", required = false },
    { name = "transaction_timezone", type = "string", required = false },
    { name = "transaction_amount", type = "decimal(18,2)", required = false },
    { name = "transaction_original_amount", type = "decimal(18,2)", required = false },
    { name = "currency", type = "string", required = false },
    { name = "original_currency", type = "string", required = false },
    { name = "exchange_rate", type = "decimal(10,6)", required = false },
    { name = "transaction_status", type = "string", required = false },
    { name = "transaction_description", type = "string", required = false },
    { name = "transaction_category", type = "string", required = false },
    { name = "transaction_subcategory", type = "string", required = false },
    # Customer fields
    { name = "customer_id", type = "string", required = false },
    { name = "customer_uuid", type = "string", required = false },
    { name = "customer_age", type = "int", required = false },
    { name = "customer_gender", type = "string", required = false },
    { name = "customer_income", type = "int", required = false },
    { name = "customer_income_range", type = "string", required = false },
    { name = "customer_marital_status", type = "string", required = false },
    { name = "customer_residence_country", type = "string", required = false },
    { name = "customer_residence_state", type = "string", required = false },
    { name = "customer_residence_city", type = "string", required = false },
    { name = "customer_residence_zip", type = "string", required = false },
    { name = "customer_kyc_status", type = "string", required = false },
    { name = "customer_employment_status", type = "string", required = false },
    { name = "customer_education_level", type = "string", required = false },
    { name = "customer_risk_category", type = "string", required = false },
    { name = "customer_vip_flag", type = "boolean", required = false },
    { name = "customer_loyalty_tier", type = "string", required = false },
    { name = "customer_marketing_opt_in", type = "boolean", required = false },
    { name = "customer_segment", type = "string", required = false },
    { name = "customer_account_tenure_years", type = "int", required = false },
    { name = "customer_loyalty_points", type = "int", required = false },
    # Merchant fields
    { name = "merchant_id", type = "string", required = false },
    { name = "merchant_name", type = "string", required = false },
    { name = "merchant_category_code", type = "string", required = false },
    { name = "merchant_category", type = "string", required = false },
    { name = "merchant_subcategory", type = "string", required = false },
    { name = "merchant_rating", type = "decimal(3,2)", required = false },
    { name = "merchant_country", type = "string", required = false },
    { name = "merchant_state", type = "string", required = false },
    { name = "merchant_city", type = "string", required = false },
    { name = "merchant_zip", type = "string", required = false },
    { name = "merchant_average_txn_value", type = "decimal(18,2)", required = false },
    { name = "merchant_chargeback_rate", type = "decimal(5,4)", required = false },
    { name = "merchant_high_risk_flag", type = "boolean", required = false },
    # Payment fields
    { name = "payment_method", type = "string", required = false },
    { name = "payment_method_type", type = "string", required = false },
    { name = "payment_method_subtype", type = "string", required = false },
    { name = "payment_card_last_four", type = "string", required = false },
    { name = "payment_card_expiry", type = "string", required = false },
    { name = "payment_card_issuer", type = "string", required = false },
    { name = "payment_card_country", type = "string", required = false },
    { name = "payment_card_funding_type", type = "string", required = false },
    { name = "payment_card_level", type = "string", required = false },
    { name = "payment_card_bin", type = "string", required = false },
    # IP and geolocation fields
    { name = "ip_address", type = "string", required = false },
    { name = "ip_geolocation_country", type = "string", required = false },
    { name = "ip_geolocation_state", type = "string", required = false },
    { name = "ip_geolocation_city", type = "string", required = false },
    { name = "ip_geolocation_zip", type = "string", required = false },
    { name = "ip_geolocation_latitude", type = "decimal(10,8)", required = false },
    { name = "ip_geolocation_longitude", type = "decimal(11,8)", required = false },
    { name = "vpn_usage_flag", type = "boolean", required = false },
    { name = "proxy_usage_flag", type = "boolean", required = false },
    { name = "tor_usage_flag", type = "boolean", required = false },
    # Fraud and risk fields
    { name = "is_fraud", type = "boolean", required = false },
    { name = "fraud_score", type = "decimal(5,2)", required = false },
    { name = "fraud_type", type = "string", required = false },
    { name = "velocity_score", type = "decimal(5,2)", required = false },
    { name = "behavioral_risk_score", type = "decimal(5,2)", required = false },
    { name = "transaction_pattern_score", type = "decimal(5,2)", required = false },
    { name = "geo_anomaly_flag", type = "boolean", required = false },
    { name = "multiple_login_flag", type = "boolean", required = false },
    { name = "high_risk_ip_flag", type = "boolean", required = false },
    { name = "account_takeover_risk_score", type = "decimal(5,2)", required = false },
    { name = "chargeback_history_flag", type = "boolean", required = false },
    { name = "previous_fraud_flag", type = "boolean", required = false },
    { name = "is_international", type = "boolean", required = false },
    { name = "cross_border_flag", type = "boolean", required = false },
    { name = "high_risk_country_flag", type = "boolean", required = false },
    # Transaction history and analytics fields
    { name = "transaction_count_7d", type = "int", required = false },
    { name = "transaction_amount_7d", type = "decimal(18,2)", required = false },
    { name = "avg_transaction_amount_7d", type = "decimal(18,2)", required = false },
    { name = "max_transaction_amount_7d", type = "decimal(18,2)", required = false },
    { name = "transaction_count_30d", type = "int", required = false },
    { name = "transaction_amount_30d", type = "decimal(18,2)", required = false },
    { name = "avg_transaction_amount_30d", type = "decimal(18,2)", required = false },
    { name = "max_transaction_amount_30d", type = "decimal(18,2)", required = false },
    { name = "transaction_count_90d", type = "int", required = false },
    { name = "transaction_amount_90d", type = "decimal(18,2)", required = false },
    { name = "transaction_count_365d", type = "int", required = false },
    { name = "transaction_amount_365d", type = "decimal(18,2)", required = false },
    { name = "online_transaction_ratio_30d", type = "decimal(5,4)", required = false },
    { name = "average_daily_transactions_30d", type = "decimal(18,2)", required = false },
    { name = "days_active_last_30d", type = "int", required = false },
  ]

  brokerage_schema = [
    # Core Order Details
    { name = "order_id", type = "string", required = true },
    { name = "parent_order_id", type = "string", required = false },
    { name = "client_order_id", type = "string", required = false },
    { name = "order_type", type = "string", required = false },
    { name = "order_side", type = "string", required = false },
    { name = "order_status", type = "string", required = false },
    { name = "time_in_force", type = "string", required = false },
    { name = "timestamp", type = "timestamp", required = false },
    { name = "order_date", type = "date", required = false },
    { name = "order_time", type = "string", required = false },
    { name = "order_timezone", type = "string", required = false },
    { name = "quantity", type = "long", required = false },
    { name = "filled_quantity", type = "long", required = false },
    { name = "remaining_quantity", type = "long", required = false },
    { name = "disclosed_quantity", type = "long", required = false },
    { name = "minimum_quantity", type = "long", required = false },
    # Security Information
    { name = "security_id", type = "string", required = false },
    { name = "symbol", type = "string", required = false },
    { name = "security_type", type = "string", required = false },
    { name = "security_name", type = "string", required = false },
    { name = "cusip", type = "string", required = false },
    { name = "isin", type = "string", required = false },
    { name = "sedol", type = "string", required = false },
    { name = "exchange", type = "string", required = false },
    { name = "primary_exchange", type = "string", required = false },
    { name = "currency", type = "string", required = false },
    { name = "country_of_issue", type = "string", required = false },
    { name = "sector", type = "string", required = false },
    { name = "industry", type = "string", required = false },
    { name = "market_cap_category", type = "string", required = false },
    { name = "underlying_symbol", type = "string", required = false },
    { name = "option_type", type = "string", required = false },
    { name = "strike_price", type = "double", required = false },
    { name = "expiration_date", type = "date", required = false },
    { name = "days_to_expiration", type = "long", required = false },
    # Account & Customer Information
    { name = "account_id", type = "string", required = false },
    { name = "account_type", type = "string", required = false },
    { name = "account_name", type = "string", required = false },
    { name = "account_status", type = "string", required = false },
    { name = "account_balance", type = "double", required = false },
    { name = "account_equity", type = "double", required = false },
    { name = "buying_power", type = "double", required = false },
    { name = "margin_balance", type = "double", required = false },
    { name = "day_trading_buying_power", type = "double", required = false },
    { name = "net_liquidation_value", type = "double", required = false },
    { name = "pattern_day_trader_flag", type = "boolean", required = false },
    { name = "customer_id", type = "string", required = false },
    { name = "customer_uuid", type = "string", required = false },
    { name = "customer_age", type = "long", required = false },
    { name = "customer_gender", type = "string", required = false },
    { name = "customer_income", type = "long", required = false },
    { name = "customer_income_range", type = "string", required = false },
    { name = "customer_marital_status", type = "string", required = false },
    { name = "customer_residence_country", type = "string", required = false },
    { name = "customer_residence_state", type = "string", required = false },
    { name = "customer_residence_city", type = "string", required = false },
    { name = "customer_residence_zip", type = "string", required = false },
    { name = "customer_kyc_status", type = "string", required = false },
    { name = "customer_employment_status", type = "string", required = false },
    { name = "customer_education_level", type = "string", required = false },
    { name = "customer_risk_category", type = "string", required = false },
    { name = "customer_vip_flag", type = "boolean", required = false },
    { name = "customer_loyalty_tier", type = "string", required = false },
    { name = "customer_marketing_opt_in", type = "boolean", required = false },
    { name = "customer_segment", type = "string", required = false },
    { name = "customer_account_tenure_years", type = "long", required = false },
    { name = "customer_loyalty_points", type = "long", required = false },
    # Order Execution Details
    { name = "price", type = "double", required = false },
    { name = "stop_price", type = "double", required = false },
    { name = "limit_price", type = "double", required = false },
    { name = "average_fill_price", type = "double", required = false },
    { name = "last_fill_price", type = "double", required = false },
    { name = "last_fill_quantity", type = "long", required = false },
    { name = "total_fill_value", type = "double", required = false },
    { name = "execution_instructions", type = "string", required = false },
    { name = "routing_destination", type = "string", required = false },
    { name = "order_capacity", type = "string", required = false },
    { name = "liquidity_indicator", type = "string", required = false },
    { name = "execution_venue", type = "string", required = false },
    { name = "contra_broker", type = "string", required = false },
    { name = "execution_id", type = "string", required = false },
    { name = "trade_id", type = "string", required = false },
    # Risk and Compliance
    { name = "pre_trade_risk_check", type = "string", required = false },
    { name = "post_trade_risk_check", type = "string", required = false },
    { name = "position_limit_check", type = "string", required = false },
    { name = "credit_limit_check", type = "string", required = false },
    { name = "regulatory_check", type = "string", required = false },
    { name = "wash_sale_flag", type = "boolean", required = false },
    { name = "short_sale_exempt_flag", type = "boolean", required = false },
    { name = "locate_required_flag", type = "boolean", required = false },
    { name = "locate_id", type = "string", required = false },
    { name = "best_execution_venue", type = "string", required = false },
    { name = "order_handling_instructions", type = "string", required = false },
    # Market Data and Pricing
    { name = "bid_price", type = "double", required = false },
    { name = "ask_price", type = "double", required = false },
    { name = "bid_size", type = "long", required = false },
    { name = "ask_size", type = "long", required = false },
    { name = "last_trade_price", type = "double", required = false },
    { name = "last_trade_size", type = "long", required = false },
    { name = "volume", type = "long", required = false },
    { name = "vwap", type = "double", required = false },
    { name = "open_price", type = "double", required = false },
    { name = "high_price", type = "double", required = false },
    { name = "low_price", type = "double", required = false },
    { name = "close_price", type = "double", required = false },
    { name = "previous_close", type = "double", required = false },
    { name = "price_change", type = "double", required = false },
    { name = "price_change_percent", type = "double", required = false },
    { name = "volatility", type = "double", required = false },
    { name = "beta", type = "double", required = false },
    # Settlement and Clearing
    { name = "settlement_date", type = "date", required = false },
    { name = "clearing_firm", type = "string", required = false },
    { name = "clearing_account", type = "string", required = false },
    { name = "settlement_currency", type = "string", required = false },
    { name = "settlement_amount", type = "double", required = false },
    { name = "accrued_interest", type = "double", required = false },
    { name = "commission", type = "double", required = false },
    { name = "sec_fee", type = "double", required = false },
    { name = "taf_fee", type = "double", required = false },
    { name = "other_fees", type = "double", required = false },
    { name = "net_settlement_amount", type = "double", required = false },
    # Regulatory and Reporting
    { name = "regulatory_transaction_id", type = "string", required = false },
    { name = "cat_reporter_id", type = "string", required = false },
    { name = "oats_reportable", type = "boolean", required = false },
    { name = "large_trader_flag", type = "boolean", required = false },
    { name = "institutional_account_flag", type = "boolean", required = false },
    { name = "employee_account_flag", type = "boolean", required = false },
    { name = "market_maker_flag", type = "boolean", required = false },
    { name = "proprietary_trading_flag", type = "boolean", required = false },
    { name = "algorithmic_trading_flag", type = "boolean", required = false },
    { name = "high_frequency_trading_flag", type = "boolean", required = false },
    { name = "dark_pool_flag", type = "boolean", required = false },
    { name = "cross_trading_flag", type = "boolean", required = false },
    { name = "internalization_flag", type = "boolean", required = false },
    # Performance and Analytics
    { name = "order_latency_ms", type = "long", required = false },
    { name = "fill_rate", type = "double", required = false },
    { name = "slippage", type = "double", required = false },
    { name = "implementation_shortfall", type = "double", required = false },
    { name = "market_impact", type = "double", required = false },
    { name = "timing_cost", type = "double", required = false },
    { name = "opportunity_cost", type = "double", required = false },
    { name = "arrival_price", type = "double", required = false },
    { name = "decision_price", type = "double", required = false },
    { name = "benchmark_price", type = "double", required = false },
    { name = "participation_rate", type = "double", required = false },
    { name = "order_aggressiveness", type = "double", required = false },
    { name = "market_conditions", type = "string", required = false },
    # Historical Metrics
    { name = "orders_count_7d", type = "long", required = false },
    { name = "orders_count_30d", type = "long", required = false },
    { name = "total_volume_7d", type = "long", required = false },
    { name = "total_volume_30d", type = "long", required = false },
    { name = "avg_order_size_7d", type = "double", required = false },
    { name = "avg_order_size_30d", type = "double", required = false },
    { name = "success_rate_7d", type = "double", required = false },
    { name = "success_rate_30d", type = "double", required = false },
    # Location and IP Information
    { name = "ip_address", type = "string", required = false },
    { name = "ip_geolocation_country", type = "string", required = false },
    { name = "ip_geolocation_state", type = "string", required = false },
    { name = "ip_geolocation_city", type = "string", required = false },
    { name = "ip_geolocation_zip", type = "string", required = false },
    { name = "ip_geolocation_latitude", type = "double", required = false },
    { name = "ip_geolocation_longitude", type = "double", required = false },
    { name = "vpn_usage_flag", type = "boolean", required = false },
    { name = "proxy_usage_flag", type = "boolean", required = false },
    { name = "tor_usage_flag", type = "boolean", required = false },
    # Risk and Fraud Indicators
    { name = "is_fraud", type = "boolean", required = false },
    { name = "fraud_score", type = "double", required = false },
    { name = "fraud_type", type = "string", required = false },
    { name = "velocity_score", type = "double", required = false },
    { name = "behavioral_risk_score", type = "double", required = false },
    { name = "transaction_pattern_score", type = "double", required = false },
    { name = "geo_anomaly_flag", type = "boolean", required = false },
    { name = "multiple_login_flag", type = "boolean", required = false },
    { name = "high_risk_ip_flag", type = "boolean", required = false },
    { name = "account_takeover_risk_score", type = "double", required = false },
    { name = "chargeback_history_flag", type = "boolean", required = false },
    { name = "previous_fraud_flag", type = "boolean", required = false },
    { name = "is_international", type = "boolean", required = false },
    { name = "cross_border_flag", type = "boolean", required = false },
    { name = "high_risk_country_flag", type = "boolean", required = false },
  ]

  # ---------------------------------------------------------------------------
  # Connect schemas — used by Path 2 (Flink jobs). Deliberately identical to the
  # Glue tables created in iac/roots/foundation/glue-databases (which iterate the
  # same base schema as-is). Keeping the two representations in sync means a
  # Flink job can load the schema from Glue and write the exact same RowData to
  # both catalogs (Glue + S3 Tables).
  #
  # The previous pipeline (MSK Connect + Debezium SMT) required type overrides
  # (timestamp→string, date→string) and extra `__op`/`__source_ts_ms` columns
  # to match what the JSON converter emitted. Flink does type-aware conversion
  # natively, so those contortions are no longer needed.
  # ---------------------------------------------------------------------------
  connect_oracle_financial_schema = local.financial_schema
  connect_oracle_brokerage_schema = local.brokerage_schema
  connect_aurora_financial_schema = local.financial_schema
  connect_aurora_brokerage_schema = local.brokerage_schema
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_kms_key" "ssm_kms_key" {
  key_id = "alias/${var.APP}-${var.ENV}-systems-manager-secret-key"
}

data "aws_kms_key" "s3_kms_key" {
  key_id = "alias/${var.APP}-${var.ENV}-s3-secret-key"
}

# -----------------------------------------------------------------------------
# S3 Tables Bucket Policy — grant Athena & Glue service principals access
# Without this, the Glue federated catalog cannot resolve the S3 Tables bucket
# and Lake Formation grant-permissions calls fail with "bucket does not exist".
# Ref: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-tables-integrating-aws.html
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "table_bucket_policy" {
  statement {
    sid    = "AllowAthenaAccess"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["athena.amazonaws.com"]
    }
    actions = ["s3tables:*"]
    resources = [
      aws_s3tables_table_bucket.iceberg_tables.arn,
      "${aws_s3tables_table_bucket.iceberg_tables.arn}/*"
    ]
  }

  statement {
    sid    = "AllowGlueAccess"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
    actions = ["s3tables:*"]
    resources = [
      aws_s3tables_table_bucket.iceberg_tables.arn,
      "${aws_s3tables_table_bucket.iceberg_tables.arn}/*"
    ]
  }

  statement {
    sid    = "AllowLakeFormationAccess"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lakeformation.amazonaws.com"]
    }
    actions = ["s3tables:*"]
    resources = [
      aws_s3tables_table_bucket.iceberg_tables.arn,
      "${aws_s3tables_table_bucket.iceberg_tables.arn}/*"
    ]
  }
}

terraform {
  required_version = ">= 1.8.0"
}

# -----------------------------------------------------------------------------
# S3 Tables Table Bucket
# -----------------------------------------------------------------------------

resource "aws_s3tables_table_bucket" "iceberg_tables" {
  name = "${var.APP}-${var.ENV}-iceberg-table-bucket"

  encryption_configuration = {
    sse_algorithm = "aws:kms"
    kms_key_arn   = data.aws_kms_key.s3_kms_key.arn
  }

  maintenance_configuration = {
    iceberg_unreferenced_file_removal = {
      status = "enabled"
      settings = {
        non_current_days  = 7
        unreferenced_days = 3
      }
    }
  }
}

resource "aws_s3tables_table_bucket_policy" "iceberg_tables" {
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  resource_policy  = data.aws_iam_policy_document.table_bucket_policy.json
}

# -----------------------------------------------------------------------------
# Analytics Integration — Lake Formation + Glue Federated Catalog
# Per: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-tables-integrating-aws.html
# -----------------------------------------------------------------------------

# IAM role for Lake Formation to access S3 Tables
resource "aws_iam_role" "s3_tables_lakeformation" {
  name = "${var.APP}-${var.ENV}-s3tables-lf-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LakeFormationDataAccessPolicy"
        Effect = "Allow"
        Principal = {
          Service = "lakeformation.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:SetContext",
          "sts:SetSourceIdentity"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
        }
      }
    ]
  })

  tags = local.tags
}

# S3 Tables permissions for the Lake Formation service role.
# Without these, Lake Formation cannot federate S3 Tables data to Glue/Athena.
# Ref: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-tables-integrating-aws.html
resource "aws_iam_role_policy" "s3_tables_lakeformation" {
  name = "${var.APP}-${var.ENV}-s3tables-lf-policy"
  role = aws_iam_role.s3_tables_lakeformation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LakeFormationPermissionsForS3ListTableBucket"
        Effect   = "Allow"
        Action   = ["s3tables:ListTableBuckets"]
        Resource = ["*"]
      },
      {
        Sid    = "LakeFormationDataAccessPermissionsForS3TableBucket"
        Effect = "Allow"
        Action = [
          "s3tables:CreateTableBucket",
          "s3tables:GetTableBucket",
          "s3tables:CreateNamespace",
          "s3tables:GetNamespace",
          "s3tables:ListNamespaces",
          "s3tables:DeleteNamespace",
          "s3tables:DeleteTableBucket",
          "s3tables:CreateTable",
          "s3tables:DeleteTable",
          "s3tables:GetTable",
          "s3tables:ListTables",
          "s3tables:RenameTable",
          "s3tables:UpdateTableMetadataLocation",
          "s3tables:GetTableMetadataLocation",
          "s3tables:GetTableData",
          "s3tables:PutTableData"
        ]
        Resource = [
          "arn:aws:s3tables:${local.region}:${local.account_id}:bucket/*"
        ]
      },
      {
        Sid    = "KMSDecryptForS3TablesEncryption"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = [
          data.aws_kms_key.s3_kms_key.arn
        ]
      }
    ]
  })
}

# Register ALL S3 Tables buckets with Lake Formation using the wildcard ARN.
# This is the standard pattern for the native "s3tablescatalog" federated catalog.
# The wildcard ARN auto-discovers all S3 Tables buckets in the account/region.
resource "aws_lakeformation_resource" "s3_tables" {
  arn                    = "arn:aws:s3tables:${local.region}:${local.account_id}:bucket/*"
  role_arn               = aws_iam_role.s3_tables_lakeformation.arn
  with_federation        = true
  with_privileged_access = true

  depends_on = [
    aws_s3tables_table_bucket.iceberg_tables,
    aws_iam_role_policy.s3_tables_lakeformation,
    time_sleep.wait_for_bucket
  ]
}

resource "time_sleep" "wait_for_bucket" {
  depends_on      = [aws_s3tables_table_bucket.iceberg_tables, aws_s3tables_table_bucket_policy.iceberg_tables]
  create_duration = "60s"
}

resource "time_sleep" "wait_for_lf_registration" {
  depends_on      = [aws_lakeformation_resource.s3_tables]
  create_duration = "30s"
}

# Glue federated catalog for S3 Tables — enables Athena/Redshift queries.
# Uses the native "s3tablescatalog" name with the wildcard bucket/* identifier.
# This is the AWS-standard catalog name that auto-discovers all S3 Tables buckets.
# Query via Athena using CHILD catalog: SELECT * FROM "s3tablescatalog/<bucket-name>"."namespace"."table"
# Example: SELECT * FROM "s3tablescatalog/${APP}-${ENV}-iceberg-table-bucket"."${APP}_${ENV}_c_oracle"."fin"
# NOTE: No aws_glue_catalog TF resource exists yet, using CLI via local-exec.
resource "terraform_data" "s3tables_glue_catalog" {
  depends_on = [time_sleep.wait_for_lf_registration]

  provisioner "local-exec" {
    command = <<-EOT
      aws glue create-catalog \
        --region ${local.region} \
        --name s3tablescatalog \
        --catalog-input '{
          "FederatedCatalog": {
            "Identifier": "arn:aws:s3tables:${local.region}:${local.account_id}:bucket/*",
            "ConnectionName": "aws:s3tables"
          },
          "CreateDatabaseDefaultPermissions": [],
          "CreateTableDefaultPermissions": [],
          "AllowFullTableExternalDataAccess": "True"
        }' 2>&1 || true
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws glue delete-catalog --name s3tablescatalog 2>&1 || true"
  }
}

# -----------------------------------------------------------------------------
# Namespaces — one per data source
# -----------------------------------------------------------------------------

resource "aws_s3tables_namespace" "oracle" {
  namespace        = "${var.APP}_${var.ENV}_c_oracle"
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn

  depends_on = [terraform_data.s3tables_glue_catalog]
}

resource "aws_s3tables_namespace" "aurora" {
  namespace        = "${var.APP}_${var.ENV}_c_aurora"
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn

  depends_on = [terraform_data.s3tables_glue_catalog]
}

resource "aws_s3tables_namespace" "cockroach" {
  namespace        = "${var.APP}_${var.ENV}_c_crdb"
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn

  depends_on = [terraform_data.s3tables_glue_catalog]
}

resource "aws_s3tables_namespace" "msk_source" {
  namespace        = "${var.APP}_${var.ENV}_c_msk_src"
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn

  depends_on = [terraform_data.s3tables_glue_catalog]
}

# -----------------------------------------------------------------------------
# Tables — financial + brokerage per namespace (8 tables total)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Connect Tables — Oracle + Aurora (Path 2, Avro-aligned schemas)
#
# With decimal.handling.mode=precise + Avro converter:
# - Oracle: NUMBER(p,s) → decimal(p,s), bare NUMBER → decimal(10,0),
#   NUMBER(1) → decimal(1,0), VARCHAR2 → string. UPPERCASE column names.
# - Aurora: DECIMAL(p,s) → decimal(p,s), INTEGER → int, BOOLEAN → boolean,
#   VARCHAR → string. Brokerage "double" fields are PG DECIMAL(19,2) → decimal(19,2).
#   lowercase column names.
# - timestamp/date source columns are VARCHAR/VARCHAR2 in both DBs → string
# -----------------------------------------------------------------------------

# ── Oracle Connect Tables ─────────────────────────────────────────────────────

resource "aws_s3tables_table" "connect_oracle_financial" {
  name             = "fin"
  namespace        = aws_s3tables_namespace.oracle.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.connect_oracle_financial_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

resource "aws_s3tables_table" "connect_oracle_brokerage" {
  name             = "brk"
  namespace        = aws_s3tables_namespace.oracle.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.connect_oracle_brokerage_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

# ── Aurora Connect Tables ─────────────────────────────────────────────────────

resource "aws_s3tables_table" "connect_aurora_financial" {
  name             = "fin"
  namespace        = aws_s3tables_namespace.aurora.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.connect_aurora_financial_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

resource "aws_s3tables_table" "connect_aurora_brokerage" {
  name             = "brk"
  namespace        = aws_s3tables_namespace.aurora.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.connect_aurora_brokerage_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

# ── CockroachDB Connect Tables ────────────────────────────────────────────────

resource "aws_s3tables_table" "connect_cockroach_financial" {
  name             = "fin"
  namespace        = aws_s3tables_namespace.cockroach.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.financial_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

resource "aws_s3tables_table" "connect_cockroach_brokerage" {
  name             = "brk"
  namespace        = aws_s3tables_namespace.cockroach.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.brokerage_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

# ── MSK Source Connect Tables ─────────────────────────────────────────────────

resource "aws_s3tables_table" "connect_msk_src_financial" {
  name             = "fin"
  namespace        = aws_s3tables_namespace.msk_source.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.financial_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

resource "aws_s3tables_table" "connect_msk_src_brokerage" {
  name             = "brk"
  namespace        = aws_s3tables_namespace.msk_source.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.brokerage_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Firehose Namespaces — one per data source (Path 1)
# -----------------------------------------------------------------------------

resource "aws_s3tables_namespace" "firehose_oracle" {
  namespace        = "${var.APP}_${var.ENV}_f_oracle"
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn

  depends_on = [terraform_data.s3tables_glue_catalog]
}

resource "aws_s3tables_namespace" "firehose_aurora" {
  namespace        = "${var.APP}_${var.ENV}_f_aurora"
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn

  depends_on = [terraform_data.s3tables_glue_catalog]
}

resource "aws_s3tables_namespace" "firehose_cockroach" {
  namespace        = "${var.APP}_${var.ENV}_f_crdb"
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn

  depends_on = [terraform_data.s3tables_glue_catalog]
}

resource "aws_s3tables_namespace" "firehose_msk_source" {
  namespace        = "${var.APP}_${var.ENV}_f_msk_src"
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn

  depends_on = [terraform_data.s3tables_glue_catalog]
}

# -----------------------------------------------------------------------------
# Firehose Tables — financial + brokerage per namespace (8 tables)
# -----------------------------------------------------------------------------

# Oracle
resource "aws_s3tables_table" "firehose_oracle_financial" {
  name             = "fin"
  namespace        = aws_s3tables_namespace.firehose_oracle.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.financial_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

resource "aws_s3tables_table" "firehose_oracle_brokerage" {
  name             = "brk"
  namespace        = aws_s3tables_namespace.firehose_oracle.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.brokerage_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

# Aurora
resource "aws_s3tables_table" "firehose_aurora_financial" {
  name             = "fin"
  namespace        = aws_s3tables_namespace.firehose_aurora.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.financial_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

resource "aws_s3tables_table" "firehose_aurora_brokerage" {
  name             = "brk"
  namespace        = aws_s3tables_namespace.firehose_aurora.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.brokerage_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

# CockroachDB
resource "aws_s3tables_table" "firehose_cockroach_financial" {
  name             = "fin"
  namespace        = aws_s3tables_namespace.firehose_cockroach.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.financial_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

resource "aws_s3tables_table" "firehose_cockroach_brokerage" {
  name             = "brk"
  namespace        = aws_s3tables_namespace.firehose_cockroach.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.brokerage_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

# MSK Source
resource "aws_s3tables_table" "firehose_msk_source_financial" {
  name             = "fin"
  namespace        = aws_s3tables_namespace.firehose_msk_source.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.financial_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

resource "aws_s3tables_table" "firehose_msk_source_brokerage" {
  name             = "brk"
  namespace        = aws_s3tables_namespace.firehose_msk_source.namespace
  table_bucket_arn = aws_s3tables_table_bucket.iceberg_tables.arn
  format           = "ICEBERG"

  maintenance_configuration = local.table_maintenance

  metadata {
    iceberg {
      schema {
        dynamic "field" {
          for_each = local.brokerage_schema
          content {
            name     = field.value.name
            type     = field.value.type
            required = field.value.required
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# SSM Parameters — share table bucket ARN and namespace details with other roots
# -----------------------------------------------------------------------------

resource "aws_ssm_parameter" "s3_table_bucket_arn" {
  name   = "/${var.APP}/${var.ENV}/s3-table-bucket-arn"
  type   = "SecureString"
  value  = aws_s3tables_table_bucket.iceberg_tables.arn
  key_id = data.aws_kms_key.ssm_kms_key.arn

  tags = local.tags
}

resource "aws_ssm_parameter" "s3_table_bucket_name" {
  name   = "/${var.APP}/${var.ENV}/s3-table-bucket-name"
  type   = "SecureString"
  value  = aws_s3tables_table_bucket.iceberg_tables.name
  key_id = data.aws_kms_key.ssm_kms_key.arn

  tags = local.tags
}
