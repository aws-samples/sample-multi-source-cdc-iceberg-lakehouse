# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# =============================================================================
# TABLE COLUMN DEFINITIONS
# =============================================================================

locals {
  # Financial transaction columns - Complete 101 fields fields matching "schemas/"
  financial_transaction_columns = [
    { name = "transaction_id", type = "string" },
    { name = "transaction_reference_id", type = "string" },
    { name = "transaction_type", type = "string" },
    { name = "transaction_subtype", type = "string" },
    { name = "timestamp", type = "timestamp" },
    { name = "transaction_date", type = "date" },
    { name = "transaction_time", type = "string" },
    { name = "transaction_timezone", type = "string" },
    { name = "transaction_amount", type = "decimal(18,2)" },
    { name = "transaction_original_amount", type = "decimal(18,2)" },
    { name = "currency", type = "string" },
    { name = "original_currency", type = "string" },
    { name = "exchange_rate", type = "decimal(10,6)" },
    { name = "transaction_status", type = "string" },
    { name = "transaction_description", type = "string" },
    { name = "transaction_category", type = "string" },
    { name = "transaction_subcategory", type = "string" },
    # Customer fields
    { name = "customer_id", type = "string" },
    { name = "customer_uuid", type = "string" },
    { name = "customer_age", type = "int" },
    { name = "customer_gender", type = "string" },
    { name = "customer_income", type = "int" },
    { name = "customer_income_range", type = "string" },
    { name = "customer_marital_status", type = "string" },
    { name = "customer_residence_country", type = "string" },
    { name = "customer_residence_state", type = "string" },
    { name = "customer_residence_city", type = "string" },
    { name = "customer_residence_zip", type = "string" },
    { name = "customer_kyc_status", type = "string" },
    { name = "customer_employment_status", type = "string" },
    { name = "customer_education_level", type = "string" },
    { name = "customer_risk_category", type = "string" },
    { name = "customer_vip_flag", type = "boolean" },
    { name = "customer_loyalty_tier", type = "string" },
    { name = "customer_marketing_opt_in", type = "boolean" },
    { name = "customer_segment", type = "string" },
    { name = "customer_account_tenure_years", type = "int" },
    { name = "customer_loyalty_points", type = "int" },
    # Merchant fields
    { name = "merchant_id", type = "string" },
    { name = "merchant_name", type = "string" },
    { name = "merchant_category_code", type = "string" },
    { name = "merchant_category", type = "string" },
    { name = "merchant_subcategory", type = "string" },
    { name = "merchant_rating", type = "decimal(3,2)" },
    { name = "merchant_country", type = "string" },
    { name = "merchant_state", type = "string" },
    { name = "merchant_city", type = "string" },
    { name = "merchant_zip", type = "string" },
    { name = "merchant_average_txn_value", type = "decimal(18,2)" },
    { name = "merchant_chargeback_rate", type = "decimal(5,4)" },
    { name = "merchant_high_risk_flag", type = "boolean" },
    # Payment fields
    { name = "payment_method", type = "string" },
    { name = "payment_method_type", type = "string" },
    { name = "payment_method_subtype", type = "string" },
    { name = "payment_card_last_four", type = "string" },
    { name = "payment_card_expiry", type = "string" },
    { name = "payment_card_issuer", type = "string" },
    { name = "payment_card_country", type = "string" },
    { name = "payment_card_funding_type", type = "string" },
    { name = "payment_card_level", type = "string" },
    { name = "payment_card_bin", type = "string" },
    # IP and geolocation fields
    { name = "ip_address", type = "string" },
    { name = "ip_geolocation_country", type = "string" },
    { name = "ip_geolocation_state", type = "string" },
    { name = "ip_geolocation_city", type = "string" },
    { name = "ip_geolocation_zip", type = "string" },
    { name = "ip_geolocation_latitude", type = "decimal(10,8)" },
    { name = "ip_geolocation_longitude", type = "decimal(11,8)" },
    { name = "vpn_usage_flag", type = "boolean" },
    { name = "proxy_usage_flag", type = "boolean" },
    { name = "tor_usage_flag", type = "boolean" },
    # Fraud and risk fields
    { name = "is_fraud", type = "boolean" },
    { name = "fraud_score", type = "decimal(5,2)" },
    { name = "fraud_type", type = "string" },
    { name = "velocity_score", type = "decimal(5,2)" },
    { name = "behavioral_risk_score", type = "decimal(5,2)" },
    { name = "transaction_pattern_score", type = "decimal(5,2)" },
    { name = "geo_anomaly_flag", type = "boolean" },
    { name = "multiple_login_flag", type = "boolean" },
    { name = "high_risk_ip_flag", type = "boolean" },
    { name = "account_takeover_risk_score", type = "decimal(5,2)" },
    { name = "chargeback_history_flag", type = "boolean" },
    { name = "previous_fraud_flag", type = "boolean" },
    { name = "is_international", type = "boolean" },
    { name = "cross_border_flag", type = "boolean" },
    { name = "high_risk_country_flag", type = "boolean" },
    # Transaction history and analytics fields
    { name = "transaction_count_7d", type = "int" },
    { name = "transaction_amount_7d", type = "decimal(18,2)" },
    { name = "avg_transaction_amount_7d", type = "decimal(18,2)" },
    { name = "max_transaction_amount_7d", type = "decimal(18,2)" },
    { name = "transaction_count_30d", type = "int" },
    { name = "transaction_amount_30d", type = "decimal(18,2)" },
    { name = "avg_transaction_amount_30d", type = "decimal(18,2)" },
    { name = "max_transaction_amount_30d", type = "decimal(18,2)" },
    { name = "transaction_count_90d", type = "int" },
    { name = "transaction_amount_90d", type = "decimal(18,2)" },
    { name = "transaction_count_365d", type = "int" },
    { name = "transaction_amount_365d", type = "decimal(18,2)" },
    { name = "online_transaction_ratio_30d", type = "decimal(5,4)" },
    { name = "average_daily_transactions_30d", type = "decimal(18,2)" },
    { name = "days_active_last_30d", type = "int" }
  ]

  # Brokerage transaction columns - Complete 180 fields matching "schemas/"
  brokerage_transaction_columns = [
    # Core Order Details
    { name = "order_id", type = "string", comment = "Unique order identifier" },
    { name = "parent_order_id", type = "string", comment = "Parent order identifier" },
    { name = "client_order_id", type = "string", comment = "Client order identifier" },
    { name = "order_type", type = "string", comment = "Type of order" },
    { name = "order_side", type = "string", comment = "Side of the order" },
    { name = "order_status", type = "string", comment = "Current status of the order" },
    { name = "time_in_force", type = "string", comment = "Time in force for the order" },
    { name = "timestamp", type = "timestamp", comment = "Order timestamp" },
    { name = "order_date", type = "date", comment = "Order date" },
    { name = "order_time", type = "string", comment = "Order time" },
    { name = "order_timezone", type = "string", comment = "Order timezone" },
    { name = "quantity", type = "bigint", comment = "Order quantity" },
    { name = "filled_quantity", type = "bigint", comment = "Quantity filled" },
    { name = "remaining_quantity", type = "bigint", comment = "Remaining quantity" },
    { name = "disclosed_quantity", type = "bigint", comment = "Disclosed quantity" },
    { name = "minimum_quantity", type = "bigint", comment = "Minimum quantity" },

    # Security Information
    { name = "security_id", type = "string", comment = "Security identifier" },
    { name = "symbol", type = "string", comment = "Trading symbol" },
    { name = "security_type", type = "string", comment = "Type of security" },
    { name = "security_name", type = "string", comment = "Security name" },
    { name = "cusip", type = "string", comment = "CUSIP identifier" },
    { name = "isin", type = "string", comment = "ISIN identifier" },
    { name = "sedol", type = "string", comment = "SEDOL identifier" },
    { name = "exchange", type = "string", comment = "Primary exchange" },
    { name = "primary_exchange", type = "string", comment = "Primary exchange" },
    { name = "currency", type = "string", comment = "Trading currency" },
    { name = "country_of_issue", type = "string", comment = "Country of issue" },
    { name = "sector", type = "string", comment = "Industry sector" },
    { name = "industry", type = "string", comment = "Industry classification" },
    { name = "market_cap_category", type = "string", comment = "Market cap category" },
    { name = "underlying_symbol", type = "string", comment = "Underlying symbol" },
    { name = "option_type", type = "string", comment = "Option type" },
    { name = "strike_price", type = "double", comment = "Strike price" },
    { name = "expiration_date", type = "date", comment = "Expiration date" },
    { name = "days_to_expiration", type = "bigint", comment = "Days to expiration" },

    # Account & Customer Information
    { name = "account_id", type = "string", comment = "Account identifier" },
    { name = "account_type", type = "string", comment = "Account type" },
    { name = "account_name", type = "string", comment = "Account name" },
    { name = "account_status", type = "string", comment = "Account status" },
    { name = "account_balance", type = "double", comment = "Account balance" },
    { name = "account_equity", type = "double", comment = "Account equity" },
    { name = "buying_power", type = "double", comment = "Buying power" },
    { name = "margin_balance", type = "double", comment = "Margin balance" },
    { name = "day_trading_buying_power", type = "double", comment = "Day trading buying power" },
    { name = "net_liquidation_value", type = "double", comment = "Net liquidation value" },
    { name = "pattern_day_trader_flag", type = "boolean", comment = "Pattern day trader flag" },
    { name = "customer_id", type = "string", comment = "Customer identifier" },
    { name = "customer_uuid", type = "string", comment = "Customer UUID" },
    { name = "customer_age", type = "bigint", comment = "Customer age" },
    { name = "customer_gender", type = "string", comment = "Customer gender" },
    { name = "customer_income", type = "bigint", comment = "Customer income" },
    { name = "customer_income_range", type = "string", comment = "Customer income range" },
    { name = "customer_marital_status", type = "string", comment = "Customer marital status" },
    { name = "customer_residence_country", type = "string", comment = "Customer residence country" },
    { name = "customer_residence_state", type = "string", comment = "Customer residence state" },
    { name = "customer_residence_city", type = "string", comment = "Customer residence city" },
    { name = "customer_residence_zip", type = "string", comment = "Customer residence zip" },
    { name = "customer_kyc_status", type = "string", comment = "Customer KYC status" },
    { name = "customer_employment_status", type = "string", comment = "Customer employment status" },
    { name = "customer_education_level", type = "string", comment = "Customer education level" },
    { name = "customer_risk_category", type = "string", comment = "Customer risk category" },
    { name = "customer_vip_flag", type = "boolean", comment = "Customer VIP flag" },
    { name = "customer_loyalty_tier", type = "string", comment = "Customer loyalty tier" },
    { name = "customer_marketing_opt_in", type = "boolean", comment = "Customer marketing opt in" },
    { name = "customer_segment", type = "string", comment = "Customer segment" },
    { name = "customer_account_tenure_years", type = "bigint", comment = "Customer account tenure years" },
    { name = "customer_loyalty_points", type = "bigint", comment = "Customer loyalty points" },

    # Order Execution Details
    { name = "price", type = "double", comment = "Order price" },
    { name = "stop_price", type = "double", comment = "Stop price" },
    { name = "limit_price", type = "double", comment = "Limit price" },
    { name = "average_fill_price", type = "double", comment = "Average fill price" },
    { name = "last_fill_price", type = "double", comment = "Last fill price" },
    { name = "last_fill_quantity", type = "bigint", comment = "Last fill quantity" },
    { name = "total_fill_value", type = "double", comment = "Total fill value" },
    { name = "execution_instructions", type = "string", comment = "Execution instructions" },
    { name = "routing_destination", type = "string", comment = "Routing destination" },
    { name = "order_capacity", type = "string", comment = "Order capacity" },
    { name = "liquidity_indicator", type = "string", comment = "Liquidity indicator" },
    { name = "execution_venue", type = "string", comment = "Execution venue" },
    { name = "contra_broker", type = "string", comment = "Contra broker" },
    { name = "execution_id", type = "string", comment = "Execution identifier" },
    { name = "trade_id", type = "string", comment = "Trade identifier" },

    # Risk and Compliance
    { name = "pre_trade_risk_check", type = "string", comment = "Pre trade risk check" },
    { name = "post_trade_risk_check", type = "string", comment = "Post trade risk check" },
    { name = "position_limit_check", type = "string", comment = "Position limit check" },
    { name = "credit_limit_check", type = "string", comment = "Credit limit check" },
    { name = "regulatory_check", type = "string", comment = "Regulatory check" },
    { name = "wash_sale_flag", type = "boolean", comment = "Wash sale flag" },
    { name = "short_sale_exempt_flag", type = "boolean", comment = "Short sale exempt flag" },
    { name = "locate_required_flag", type = "boolean", comment = "Locate required flag" },
    { name = "locate_id", type = "string", comment = "Locate identifier" },
    { name = "best_execution_venue", type = "string", comment = "Best execution venue" },
    { name = "order_handling_instructions", type = "string", comment = "Order handling instructions" },

    # Market Data and Pricing
    { name = "bid_price", type = "double", comment = "Bid price" },
    { name = "ask_price", type = "double", comment = "Ask price" },
    { name = "bid_size", type = "bigint", comment = "Bid size" },
    { name = "ask_size", type = "bigint", comment = "Ask size" },
    { name = "last_trade_price", type = "double", comment = "Last trade price" },
    { name = "last_trade_size", type = "bigint", comment = "Last trade size" },
    { name = "volume", type = "bigint", comment = "Trading volume" },
    { name = "vwap", type = "double", comment = "Volume weighted average price" },
    { name = "open_price", type = "double", comment = "Open price" },
    { name = "high_price", type = "double", comment = "High price" },
    { name = "low_price", type = "double", comment = "Low price" },
    { name = "close_price", type = "double", comment = "Close price" },
    { name = "previous_close", type = "double", comment = "Previous close" },
    { name = "price_change", type = "double", comment = "Price change" },
    { name = "price_change_percent", type = "double", comment = "Price change percent" },
    { name = "volatility", type = "double", comment = "Volatility" },
    { name = "beta", type = "double", comment = "Beta" },

    # Settlement and Clearing
    { name = "settlement_date", type = "date", comment = "Settlement date" },
    { name = "clearing_firm", type = "string", comment = "Clearing firm" },
    { name = "clearing_account", type = "string", comment = "Clearing account" },
    { name = "settlement_currency", type = "string", comment = "Settlement currency" },
    { name = "settlement_amount", type = "double", comment = "Settlement amount" },
    { name = "accrued_interest", type = "double", comment = "Accrued interest" },
    { name = "commission", type = "double", comment = "Commission" },
    { name = "sec_fee", type = "double", comment = "SEC fee" },
    { name = "taf_fee", type = "double", comment = "TAF fee" },
    { name = "other_fees", type = "double", comment = "Other fees" },
    { name = "net_settlement_amount", type = "double", comment = "Net settlement amount" },

    # Regulatory and Reporting
    { name = "regulatory_transaction_id", type = "string", comment = "Regulatory transaction ID" },
    { name = "cat_reporter_id", type = "string", comment = "CAT reporter ID" },
    { name = "oats_reportable", type = "boolean", comment = "OATS reportable" },
    { name = "large_trader_flag", type = "boolean", comment = "Large trader flag" },
    { name = "institutional_account_flag", type = "boolean", comment = "Institutional account flag" },
    { name = "employee_account_flag", type = "boolean", comment = "Employee account flag" },
    { name = "market_maker_flag", type = "boolean", comment = "Market maker flag" },
    { name = "proprietary_trading_flag", type = "boolean", comment = "Proprietary trading flag" },
    { name = "algorithmic_trading_flag", type = "boolean", comment = "Algorithmic trading flag" },
    { name = "high_frequency_trading_flag", type = "boolean", comment = "High frequency trading flag" },
    { name = "dark_pool_flag", type = "boolean", comment = "Dark pool flag" },
    { name = "cross_trading_flag", type = "boolean", comment = "Cross trading flag" },
    { name = "internalization_flag", type = "boolean", comment = "Internalization flag" },

    # Performance and Analytics
    { name = "order_latency_ms", type = "bigint", comment = "Order latency in milliseconds" },
    { name = "fill_rate", type = "double", comment = "Fill rate" },
    { name = "slippage", type = "double", comment = "Slippage" },
    { name = "implementation_shortfall", type = "double", comment = "Implementation shortfall" },
    { name = "market_impact", type = "double", comment = "Market impact" },
    { name = "timing_cost", type = "double", comment = "Timing cost" },
    { name = "opportunity_cost", type = "double", comment = "Opportunity cost" },
    { name = "arrival_price", type = "double", comment = "Arrival price" },
    { name = "decision_price", type = "double", comment = "Decision price" },
    { name = "benchmark_price", type = "double", comment = "Benchmark price" },
    { name = "participation_rate", type = "double", comment = "Participation rate" },
    { name = "order_aggressiveness", type = "double", comment = "Order aggressiveness" },
    { name = "market_conditions", type = "string", comment = "Market conditions" },

    # Historical Metrics
    { name = "orders_count_7d", type = "bigint", comment = "Orders count 7 days" },
    { name = "orders_count_30d", type = "bigint", comment = "Orders count 30 days" },
    { name = "total_volume_7d", type = "bigint", comment = "Total volume 7 days" },
    { name = "total_volume_30d", type = "bigint", comment = "Total volume 30 days" },
    { name = "avg_order_size_7d", type = "double", comment = "Average order size 7 days" },
    { name = "avg_order_size_30d", type = "double", comment = "Average order size 30 days" },
    { name = "success_rate_7d", type = "double", comment = "Success rate 7 days" },
    { name = "success_rate_30d", type = "double", comment = "Success rate 30 days" },

    # Location and IP Information
    { name = "ip_address", type = "string", comment = "IP address" },
    { name = "ip_geolocation_country", type = "string", comment = "IP geolocation country" },
    { name = "ip_geolocation_state", type = "string", comment = "IP geolocation state" },
    { name = "ip_geolocation_city", type = "string", comment = "IP geolocation city" },
    { name = "ip_geolocation_zip", type = "string", comment = "IP geolocation zip" },
    { name = "ip_geolocation_latitude", type = "double", comment = "IP geolocation latitude" },
    { name = "ip_geolocation_longitude", type = "double", comment = "IP geolocation longitude" },
    { name = "vpn_usage_flag", type = "boolean", comment = "VPN usage flag" },
    { name = "proxy_usage_flag", type = "boolean", comment = "Proxy usage flag" },
    { name = "tor_usage_flag", type = "boolean", comment = "TOR usage flag" },

    # Risk and Fraud Indicators
    { name = "is_fraud", type = "boolean", comment = "Is fraud" },
    { name = "fraud_score", type = "double", comment = "Fraud score" },
    { name = "fraud_type", type = "string", comment = "Fraud type" },
    { name = "velocity_score", type = "double", comment = "Velocity score" },
    { name = "behavioral_risk_score", type = "double", comment = "Behavioral risk score" },
    { name = "transaction_pattern_score", type = "double", comment = "Transaction pattern score" },
    { name = "geo_anomaly_flag", type = "boolean", comment = "Geo anomaly flag" },
    { name = "multiple_login_flag", type = "boolean", comment = "Multiple login flag" },
    { name = "high_risk_ip_flag", type = "boolean", comment = "High risk IP flag" },
    { name = "account_takeover_risk_score", type = "double", comment = "Account takeover risk score" },
    { name = "chargeback_history_flag", type = "boolean", comment = "Chargeback history flag" },
    { name = "previous_fraud_flag", type = "boolean", comment = "Previous fraud flag" },
    { name = "is_international", type = "boolean", comment = "Is international" },
    { name = "cross_border_flag", type = "boolean", comment = "Cross border flag" },
    { name = "high_risk_country_flag", type = "boolean", comment = "High risk country flag" }
  ]
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Transactions table
resource "aws_glue_catalog_table" "transactions_table" {

  database_name = var.DATABASE_NAME
  name          = var.TABLE_NAME
  table_type    = "EXTERNAL_TABLE"
  parameters = {
    format      = "parquet"
    primaryKeys = var.UPPERCASE_COLUMNS ? (var.TABLE_TYPE == "financial" ? "TRANSACTION_ID" : "ORDER_ID") : (var.TABLE_TYPE == "financial" ? "transaction_id" : "order_id")
  }

  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"
    }
  }
  storage_descriptor {
    location = "s3://${var.S3_BUCKET_NAME}/${var.DATABASE_NAME}/${var.TABLE_NAME}/"
    dynamic "columns" {
      for_each = var.TABLE_TYPE == "financial" ? local.financial_transaction_columns : local.brokerage_transaction_columns
      content {
        name = var.UPPERCASE_COLUMNS ? upper(columns.value.name) : columns.value.name
        type = columns.value.type
      }
    }
  }
}
