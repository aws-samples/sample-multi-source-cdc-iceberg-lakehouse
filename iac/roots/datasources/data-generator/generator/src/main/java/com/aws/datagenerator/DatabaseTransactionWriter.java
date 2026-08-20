// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.datagenerator;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import org.slf4j.LoggerFactory;
import org.slf4j.Logger;

import com.amazonaws.services.secretsmanager.AWSSecretsManager;
import com.amazonaws.services.secretsmanager.AWSSecretsManagerClientBuilder;
import com.amazonaws.services.secretsmanager.model.GetSecretValueRequest;
import com.amazonaws.services.secretsmanager.model.GetSecretValueResult;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Generic database writer that can handle different transaction types
 * with connection details retrieved from AWS Secrets Manager
 */
public class DatabaseTransactionWriter implements DataWriter {
    private static final Logger logger = LoggerFactory.getLogger(DatabaseTransactionWriter.class);
    private static final ObjectMapper objectMapper = new ObjectMapper();

    private final String secretName;
    private final String region;
    private final String tableName;
    private final boolean createTableIfNotExists;
    private final String transactionType;
    private Connection connection;
    private final AtomicInteger recordsWritten = new AtomicInteger(0);
    private final String name;

    /**
     * Constructor for DatabaseTransactionWriter
     * 
     * @param name                   Descriptive name for this writer
     * @param secretName             Name of the secret in AWS Secrets Manager
     * @param region                 AWS region where the secret is stored
     * @param tableName              Name of the table to write to
     * @param transactionType        Type of transaction (financial or brokerage)
     * @param createTableIfNotExists Whether to create the table if it doesn't exist
     */
    public DatabaseTransactionWriter(String name, String secretName, String region, String tableName,
            String transactionType, boolean createTableIfNotExists) {
        this.name = name;
        this.secretName = secretName;
        this.region = region;
        this.tableName = tableName;
        this.transactionType = transactionType;
        this.createTableIfNotExists = createTableIfNotExists;

        try {
            initializeConnection();
            if (createTableIfNotExists) {
                createTableIfNotExists();
            }
        } catch (Exception e) {
            logger.error("Failed to initialize database connection for {}", name, e);
            throw new RuntimeException("Failed to initialize database connection for " + name, e);
        }
    }

    /**
     * Initialize the database connection using credentials from AWS Secrets Manager
     */
    private void initializeConnection() throws Exception {
        logger.info("[{}] Initializing database connection using secret: {}", name, secretName);

        // Get the secret from AWS Secrets Manager
        AWSSecretsManager secretsManager = AWSSecretsManagerClientBuilder.standard()
                .withRegion(region)
                .build();

        GetSecretValueRequest getSecretValueRequest = new GetSecretValueRequest()
                .withSecretId(secretName);

        GetSecretValueResult getSecretValueResult = secretsManager.getSecretValue(getSecretValueRequest);
        String secret = getSecretValueResult.getSecretString();

        // Parse the secret JSON
        JsonNode secretJson = objectMapper.readTree(secret);
        String username = secretJson.get("username").asText();
        String password = secretJson.get("password").asText();
        String host = secretJson.get("host").asText();
        String port = secretJson.get("port").asText();
        String dbname = secretJson.get("dbname").asText();
        String engine = secretJson.get("engine").asText().toLowerCase();

        // Load database drivers explicitly
        try {
            switch (engine) {
                case "postgres":
                case "postgresql":
                    Class.forName("org.postgresql.Driver");
                    break;
                case "cockroach":
                    Class.forName("org.postgresql.Driver");
                    break;
                case "oracle":
                    Class.forName("oracle.jdbc.driver.OracleDriver");
                    break;
                default:
                    logger.warn("[{}] No explicit driver loading for engine: {}", name, engine);
            }
        } catch (ClassNotFoundException e) {
            logger.warn("[{}] Driver not found for engine {}, trying without explicit loading", name, engine, e);
        }

        // Construct JDBC URL based on the database engine
        String jdbcUrl;
        switch (engine) {
            case "postgres":
            case "postgresql":
                jdbcUrl = String.format("jdbc:postgresql://%s:%s/%s", host, port, dbname);
                break;
            case "cockroach":
                jdbcUrl = String.format("jdbc:postgresql://%s:%s/%s?sslmode=disable", host, port, dbname);
                break;
            case "oracle":
                String serviceName = dbname.toLowerCase();
                if (!serviceName.equals("xepdb1") && !serviceName.equals("xe")) {
                    logger.warn(
                            "[{}] Oracle service name '{}' may not be correct for Oracle XE. Expected 'xepdb1' or 'xe'",
                            name, serviceName);
                }
                jdbcUrl = String.format("jdbc:oracle:thin:@//%s:%s/%s", host, port, serviceName);
                break;
            default:
                throw new IllegalArgumentException("Unsupported database engine: " + engine);
        }

        logger.info("[{}] Connecting to database: {}", name, jdbcUrl);
        connection = DriverManager.getConnection(jdbcUrl, username, password);
        connection.setAutoCommit(false);
        logger.info("[{}] Database connection established successfully", name);
    }

    /**
     * Check if table exists in the database
     */
    private boolean tableExists() throws SQLException {
        try (Statement statement = connection.createStatement()) {
            String databaseProductName = connection.getMetaData().getDatabaseProductName().toLowerCase();

            String checkTableSQL;
            if (databaseProductName.contains("oracle")) {
                checkTableSQL = String.format(
                        "SELECT COUNT(*) FROM user_tables WHERE table_name = '%s'",
                        tableName.toUpperCase());
            } else {
                checkTableSQL = String.format(
                        "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '%s'",
                        tableName.toLowerCase());
            }

            try (ResultSet resultSet = statement.executeQuery(checkTableSQL)) {
                if (resultSet.next()) {
                    return resultSet.getInt(1) > 0;
                }
            }
        }
        return false;
    }

    /**
     * Create the table if it doesn't exist based on transaction type
     */
    private void createTableIfNotExists() throws SQLException {
        logger.info("[{}] Checking if table exists: {}", name, tableName);

        if (tableExists()) {
            logger.info("[{}] Table already exists: {}", name, tableName);
            return;
        }

        logger.info("[{}] Creating table: {} for transaction type: {}", name, tableName, transactionType);

        String databaseProductName = connection.getMetaData().getDatabaseProductName().toLowerCase();
        boolean isOracle = databaseProductName.contains("oracle");

        String createTableSQL;

        if ("brokerage".equalsIgnoreCase(transactionType)) {
            createTableSQL = createBrokerageTableSQL(isOracle);
        } else {
            createTableSQL = createFinancialTableSQL(isOracle);
        }

        try (Statement statement = connection.createStatement()) {
            statement.execute(createTableSQL);
            connection.commit();
            logger.info("[{}] Table created successfully: {}", name, tableName);
        } catch (SQLException e) {
            connection.rollback();
            logger.error("[{}] Failed to create table: {}", name, tableName, e);
            throw e;
        }
    }

    /**
     * Create SQL for financial transactions table
     */
    private String createFinancialTableSQL(boolean isOracle) {
        if (isOracle) {
            return String.format(
                    "CREATE TABLE %s (" +
                            "  transaction_id VARCHAR2(255) PRIMARY KEY," +
                            "  transaction_reference_id VARCHAR2(255)," +
                            "  transaction_type VARCHAR2(50)," +
                            "  transaction_subtype VARCHAR2(50)," +
                            "  timestamp VARCHAR2(50)," +
                            "  transaction_date VARCHAR2(20)," +
                            "  transaction_time VARCHAR2(20)," +
                            "  transaction_timezone VARCHAR2(50)," +
                            "  transaction_amount NUMBER(19,2)," +
                            "  transaction_original_amount NUMBER(19,2)," +
                            "  currency VARCHAR2(10)," +
                            "  original_currency VARCHAR2(10)," +
                            "  exchange_rate NUMBER(19,6)," +
                            "  transaction_status VARCHAR2(50)," +
                            "  transaction_description VARCHAR2(4000)," +
                            "  transaction_category VARCHAR2(50)," +
                            "  transaction_subcategory VARCHAR2(50)," +
                            // Customer fields
                            "  customer_id VARCHAR2(255)," +
                            "  customer_uuid VARCHAR2(36)," +
                            "  customer_age NUMBER(10,0)," +
                            "  customer_gender VARCHAR2(20)," +
                            "  customer_income NUMBER(10,0)," +
                            "  customer_income_range VARCHAR2(50)," +
                            "  customer_marital_status VARCHAR2(20)," +
                            "  customer_residence_country VARCHAR2(10)," +
                            "  customer_residence_state VARCHAR2(10)," +
                            "  customer_residence_city VARCHAR2(100)," +
                            "  customer_residence_zip VARCHAR2(20)," +
                            "  customer_kyc_status VARCHAR2(20)," +
                            "  customer_employment_status VARCHAR2(50)," +
                            "  customer_education_level VARCHAR2(50)," +
                            "  customer_risk_category VARCHAR2(20)," +
                            "  customer_vip_flag NUMBER(1) CHECK (customer_vip_flag IN (0,1))," +
                            "  customer_loyalty_tier VARCHAR2(20)," +
                            "  customer_marketing_opt_in NUMBER(1) CHECK (customer_marketing_opt_in IN (0,1))," +
                            "  customer_segment VARCHAR2(50)," +
                            "  customer_account_tenure_years NUMBER(10,0)," +
                            "  customer_loyalty_points NUMBER(10,0)," +
                            // Merchant information
                            "  merchant_id VARCHAR2(255)," +
                            "  merchant_name VARCHAR2(255)," +
                            "  merchant_category_code VARCHAR2(10)," +
                            "  merchant_category VARCHAR2(50)," +
                            "  merchant_subcategory VARCHAR2(50)," +
                            "  merchant_rating NUMBER(3,1)," +
                            "  merchant_country VARCHAR2(10)," +
                            "  merchant_state VARCHAR2(10)," +
                            "  merchant_city VARCHAR2(100)," +
                            "  merchant_zip VARCHAR2(20)," +
                            "  merchant_average_txn_value NUMBER(19,2)," +
                            "  merchant_chargeback_rate NUMBER(5,4)," +
                            "  merchant_high_risk_flag NUMBER(1) CHECK (merchant_high_risk_flag IN (0,1))," +
                            // Payment method details
                            "  payment_method VARCHAR2(50)," +
                            "  payment_method_type VARCHAR2(50)," +
                            "  payment_method_subtype VARCHAR2(100)," +
                            "  payment_card_last_four VARCHAR2(4)," +
                            "  payment_card_expiry VARCHAR2(5)," +
                            "  payment_card_issuer VARCHAR2(100)," +
                            "  payment_card_country VARCHAR2(10)," +
                            "  payment_card_funding_type VARCHAR2(20)," +
                            "  payment_card_level VARCHAR2(20)," +
                            "  payment_card_bin VARCHAR2(6)," +
                            // Risk and fraud indicators
                            "  is_fraud NUMBER(1) CHECK (is_fraud IN (0,1))," +
                            "  fraud_score NUMBER(5,2)," +
                            "  fraud_type VARCHAR2(50)," +
                            "  velocity_score NUMBER(5,2)," +
                            "  behavioral_risk_score NUMBER(5,2)," +
                            "  transaction_pattern_score NUMBER(5,2)," +
                            "  geo_anomaly_flag NUMBER(1) CHECK (geo_anomaly_flag IN (0,1))," +
                            "  multiple_login_flag NUMBER(1) CHECK (multiple_login_flag IN (0,1))," +
                            "  high_risk_ip_flag NUMBER(1) CHECK (high_risk_ip_flag IN (0,1))," +
                            "  account_takeover_risk_score NUMBER(5,2)," +
                            "  chargeback_history_flag NUMBER(1) CHECK (chargeback_history_flag IN (0,1))," +
                            "  previous_fraud_flag NUMBER(1) CHECK (previous_fraud_flag IN (0,1))," +
                            "  is_international NUMBER(1) CHECK (is_international IN (0,1))," +
                            "  cross_border_flag NUMBER(1) CHECK (cross_border_flag IN (0,1))," +
                            "  high_risk_country_flag NUMBER(1) CHECK (high_risk_country_flag IN (0,1))," +
                            // Location information
                            "  ip_address VARCHAR2(45)," +
                            "  ip_geolocation_country VARCHAR2(10)," +
                            "  ip_geolocation_state VARCHAR2(10)," +
                            "  ip_geolocation_city VARCHAR2(100)," +
                            "  ip_geolocation_zip VARCHAR2(20)," +
                            "  ip_geolocation_latitude NUMBER(10,6)," +
                            "  ip_geolocation_longitude NUMBER(10,6)," +
                            "  vpn_usage_flag NUMBER(1) CHECK (vpn_usage_flag IN (0,1))," +
                            "  proxy_usage_flag NUMBER(1) CHECK (proxy_usage_flag IN (0,1))," +
                            "  tor_usage_flag NUMBER(1) CHECK (tor_usage_flag IN (0,1))," +
                            // Transaction history metrics
                            "  transaction_count_7d NUMBER(10,0)," +
                            "  transaction_amount_7d NUMBER(19,2)," +
                            "  avg_transaction_amount_7d NUMBER(19,2)," +
                            "  max_transaction_amount_7d NUMBER(19,2)," +
                            "  transaction_count_30d NUMBER(10,0)," +
                            "  transaction_amount_30d NUMBER(19,2)," +
                            "  avg_transaction_amount_30d NUMBER(19,2)," +
                            "  max_transaction_amount_30d NUMBER(19,2)," +
                            "  transaction_count_90d NUMBER(10,0)," +
                            "  transaction_amount_90d NUMBER(19,2)," +
                            "  transaction_count_365d NUMBER(10,0)," +
                            "  transaction_amount_365d NUMBER(19,2)," +
                            "  online_transaction_ratio_30d NUMBER(5,2)," +
                            "  average_daily_transactions_30d NUMBER(19,2)," +
                            "  days_active_last_30d NUMBER(10,0)" +
                            ")",
                    tableName);
        } else {
            return String.format(
                    "CREATE TABLE IF NOT EXISTS %s (" +
                            "  transaction_id VARCHAR(255) PRIMARY KEY," +
                            "  transaction_reference_id VARCHAR(255)," +
                            "  transaction_type VARCHAR(50)," +
                            "  transaction_subtype VARCHAR(50)," +
                            "  timestamp VARCHAR(50)," +
                            "  transaction_date VARCHAR(20)," +
                            "  transaction_time VARCHAR(20)," +
                            "  transaction_timezone VARCHAR(50)," +
                            "  transaction_amount DECIMAL(19,2)," +
                            "  transaction_original_amount DECIMAL(19,2)," +
                            "  currency VARCHAR(10)," +
                            "  original_currency VARCHAR(10)," +
                            "  exchange_rate DECIMAL(19,6)," +
                            "  transaction_status VARCHAR(50)," +
                            "  transaction_description TEXT," +
                            "  transaction_category VARCHAR(50)," +
                            "  transaction_subcategory VARCHAR(50)," +
                            // Customer fields
                            "  customer_id VARCHAR(255)," +
                            "  customer_uuid VARCHAR(36)," +
                            "  customer_age INTEGER," +
                            "  customer_gender VARCHAR(20)," +
                            "  customer_income INTEGER," +
                            "  customer_income_range VARCHAR(50)," +
                            "  customer_marital_status VARCHAR(20)," +
                            "  customer_residence_country VARCHAR(10)," +
                            "  customer_residence_state VARCHAR(10)," +
                            "  customer_residence_city VARCHAR(100)," +
                            "  customer_residence_zip VARCHAR(20)," +
                            "  customer_kyc_status VARCHAR(20)," +
                            "  customer_employment_status VARCHAR(50)," +
                            "  customer_education_level VARCHAR(50)," +
                            "  customer_risk_category VARCHAR(20)," +
                            "  customer_vip_flag BOOLEAN," +
                            "  customer_loyalty_tier VARCHAR(20)," +
                            "  customer_marketing_opt_in BOOLEAN," +
                            "  customer_segment VARCHAR(50)," +
                            "  customer_account_tenure_years INTEGER," +
                            "  customer_loyalty_points INTEGER," +
                            // Merchant information
                            "  merchant_id VARCHAR(255)," +
                            "  merchant_name VARCHAR(255)," +
                            "  merchant_category_code VARCHAR(10)," +
                            "  merchant_category VARCHAR(50)," +
                            "  merchant_subcategory VARCHAR(50)," +
                            "  merchant_rating DECIMAL(3,1)," +
                            "  merchant_country VARCHAR(10)," +
                            "  merchant_state VARCHAR(10)," +
                            "  merchant_city VARCHAR(100)," +
                            "  merchant_zip VARCHAR(20)," +
                            "  merchant_average_txn_value DECIMAL(19,2)," +
                            "  merchant_chargeback_rate DECIMAL(5,4)," +
                            "  merchant_high_risk_flag BOOLEAN," +
                            // Payment method details
                            "  payment_method VARCHAR(50)," +
                            "  payment_method_type VARCHAR(50)," +
                            "  payment_method_subtype VARCHAR(100)," +
                            "  payment_card_last_four VARCHAR(4)," +
                            "  payment_card_expiry VARCHAR(5)," +
                            "  payment_card_issuer VARCHAR(100)," +
                            "  payment_card_country VARCHAR(10)," +
                            "  payment_card_funding_type VARCHAR(20)," +
                            "  payment_card_level VARCHAR(20)," +
                            "  payment_card_bin VARCHAR(6)," +
                            // Risk and fraud indicators
                            "  is_fraud BOOLEAN," +
                            "  fraud_score DECIMAL(5,2)," +
                            "  fraud_type VARCHAR(50)," +
                            "  velocity_score DECIMAL(5,2)," +
                            "  behavioral_risk_score DECIMAL(5,2)," +
                            "  transaction_pattern_score DECIMAL(5,2)," +
                            "  geo_anomaly_flag BOOLEAN," +
                            "  multiple_login_flag BOOLEAN," +
                            "  high_risk_ip_flag BOOLEAN," +
                            "  account_takeover_risk_score DECIMAL(5,2)," +
                            "  chargeback_history_flag BOOLEAN," +
                            "  previous_fraud_flag BOOLEAN," +
                            "  is_international BOOLEAN," +
                            "  cross_border_flag BOOLEAN," +
                            "  high_risk_country_flag BOOLEAN," +
                            // Location information
                            "  ip_address VARCHAR(45)," +
                            "  ip_geolocation_country VARCHAR(10)," +
                            "  ip_geolocation_state VARCHAR(10)," +
                            "  ip_geolocation_city VARCHAR(100)," +
                            "  ip_geolocation_zip VARCHAR(20)," +
                            "  ip_geolocation_latitude DECIMAL(10,6)," +
                            "  ip_geolocation_longitude DECIMAL(10,6)," +
                            "  vpn_usage_flag BOOLEAN," +
                            "  proxy_usage_flag BOOLEAN," +
                            "  tor_usage_flag BOOLEAN," +
                            // Transaction history metrics
                            "  transaction_count_7d INTEGER," +
                            "  transaction_amount_7d DECIMAL(19,2)," +
                            "  avg_transaction_amount_7d DECIMAL(19,2)," +
                            "  max_transaction_amount_7d DECIMAL(19,2)," +
                            "  transaction_count_30d INTEGER," +
                            "  transaction_amount_30d DECIMAL(19,2)," +
                            "  avg_transaction_amount_30d DECIMAL(19,2)," +
                            "  max_transaction_amount_30d DECIMAL(19,2)," +
                            "  transaction_count_90d INTEGER," +
                            "  transaction_amount_90d DECIMAL(19,2)," +
                            "  transaction_count_365d INTEGER," +
                            "  transaction_amount_365d DECIMAL(19,2)," +
                            "  online_transaction_ratio_30d DECIMAL(5,2)," +
                            "  average_daily_transactions_30d DECIMAL(19,2)," +
                            "  days_active_last_30d INTEGER" +
                            ")",
                    tableName);
        }
    }

    /**
     * Create SQL for brokerage transactions table - complete 180 field schema
     */
    private String createBrokerageTableSQL(boolean isOracle) {
        if (isOracle) {
            return String.format(
                    "CREATE TABLE %s (" +
                    // Core order fields
                            "  order_id VARCHAR2(255) PRIMARY KEY," +
                            "  parent_order_id VARCHAR2(255)," +
                            "  client_order_id VARCHAR2(255)," +
                            "  order_type VARCHAR2(50)," +
                            "  order_side VARCHAR2(50)," +
                            "  order_status VARCHAR2(50)," +
                            "  time_in_force VARCHAR2(50)," +
                            "  timestamp VARCHAR2(50)," +
                            "  order_date VARCHAR2(20)," +
                            "  order_time VARCHAR2(20)," +
                            "  order_timezone VARCHAR2(50)," +
                            "  quantity NUMBER(10,0)," +
                            "  filled_quantity NUMBER(10,0)," +
                            "  remaining_quantity NUMBER(10,0)," +
                            "  disclosed_quantity NUMBER(10,0)," +
                            "  minimum_quantity NUMBER(10,0)," +
                            // Security fields
                            "  security_id VARCHAR2(50)," +
                            "  symbol VARCHAR2(20)," +
                            "  security_type VARCHAR2(50)," +
                            "  security_name VARCHAR2(255)," +
                            "  cusip VARCHAR2(20)," +
                            "  isin VARCHAR2(20)," +
                            "  sedol VARCHAR2(20)," +
                            "  exchange VARCHAR2(50)," +
                            "  primary_exchange VARCHAR2(50)," +
                            "  currency VARCHAR2(10)," +
                            "  country_of_issue VARCHAR2(10)," +
                            "  sector VARCHAR2(100)," +
                            "  industry VARCHAR2(100)," +
                            "  market_cap_category VARCHAR2(50)," +
                            "  underlying_symbol VARCHAR2(20)," +
                            "  option_type VARCHAR2(10)," +
                            "  strike_price NUMBER(19,2)," +
                            "  expiration_date VARCHAR2(20)," +
                            "  days_to_expiration NUMBER(10,0)," +
                            // Customer and account fields
                            "  customer_id VARCHAR2(255)," +
                            "  customer_uuid VARCHAR2(36)," +
                            "  customer_age NUMBER(10,0)," +
                            "  customer_gender VARCHAR2(20)," +
                            "  customer_income NUMBER(10,0)," +
                            "  customer_income_range VARCHAR2(50)," +
                            "  customer_account_tenure_years NUMBER(10,0)," +
                            "  customer_education_level VARCHAR2(50)," +
                            "  customer_employment_status VARCHAR2(50)," +
                            "  customer_kyc_status VARCHAR2(20)," +
                            "  customer_loyalty_points NUMBER(10,0)," +
                            "  customer_loyalty_tier VARCHAR2(20)," +
                            "  customer_marital_status VARCHAR2(20)," +
                            "  customer_marketing_opt_in NUMBER(1)," +
                            "  customer_residence_city VARCHAR2(100)," +
                            "  customer_residence_country VARCHAR2(10)," +
                            "  customer_residence_state VARCHAR2(10)," +
                            "  customer_residence_zip VARCHAR2(20)," +
                            "  customer_risk_category VARCHAR2(20)," +
                            "  customer_segment VARCHAR2(50)," +
                            "  customer_vip_flag NUMBER(1)," +
                            "  account_id VARCHAR2(255)," +
                            "  account_type VARCHAR2(50)," +
                            "  account_name VARCHAR2(255)," +
                            "  account_status VARCHAR2(50)," +
                            "  account_balance NUMBER(19,2)," +
                            "  account_equity NUMBER(19,2)," +
                            "  buying_power NUMBER(19,2)," +
                            "  day_trading_buying_power NUMBER(19,2)," +
                            "  margin_balance NUMBER(19,2)," +
                            "  net_liquidation_value NUMBER(19,2)," +
                            // Pricing and market data fields
                            "  price NUMBER(19,2)," +
                            "  stop_price NUMBER(19,2)," +
                            "  limit_price NUMBER(19,2)," +
                            "  average_fill_price NUMBER(19,2)," +
                            "  last_fill_price NUMBER(19,2)," +
                            "  last_fill_quantity NUMBER(10,0)," +
                            "  total_fill_value NUMBER(19,2)," +
                            "  bid_price NUMBER(19,2)," +
                            "  ask_price NUMBER(19,2)," +
                            "  bid_size NUMBER(10,0)," +
                            "  ask_size NUMBER(10,0)," +
                            "  last_trade_price NUMBER(19,2)," +
                            "  last_trade_size NUMBER(10,0)," +
                            "  open_price NUMBER(19,2)," +
                            "  high_price NUMBER(19,2)," +
                            "  low_price NUMBER(19,2)," +
                            "  close_price NUMBER(19,2)," +
                            "  previous_close NUMBER(19,2)," +
                            "  price_change NUMBER(19,2)," +
                            "  price_change_percent NUMBER(19,2)," +
                            "  volume NUMBER(10,0)," +
                            "  vwap NUMBER(19,2)," +
                            "  volatility NUMBER(19,2)," +
                            "  beta NUMBER(19,2)," +
                            // Execution and trading fields
                            "  execution_id VARCHAR2(255)," +
                            "  execution_venue VARCHAR2(100)," +
                            "  execution_instructions VARCHAR2(500)," +
                            "  order_handling_instructions VARCHAR2(4000)," +
                            "  routing_destination VARCHAR2(100)," +
                            "  best_execution_venue VARCHAR2(100)," +
                            "  liquidity_indicator VARCHAR2(20)," +
                            "  order_capacity VARCHAR2(20)," +
                            "  trade_id VARCHAR2(255)," +
                            "  regulatory_transaction_id VARCHAR2(255)," +
                            "  cat_reporter_id VARCHAR2(50)," +
                            // Fees and settlement
                            "  commission NUMBER(19,2)," +
                            "  sec_fee NUMBER(19,2)," +
                            "  taf_fee NUMBER(19,2)," +
                            "  other_fees NUMBER(19,2)," +
                            "  settlement_amount NUMBER(19,2)," +
                            "  net_settlement_amount NUMBER(19,2)," +
                            "  settlement_currency VARCHAR2(10)," +
                            "  settlement_date VARCHAR2(20)," +
                            "  accrued_interest NUMBER(19,2)," +
                            // Risk and compliance fields
                            "  pre_trade_risk_check VARCHAR2(50)," +
                            "  post_trade_risk_check VARCHAR2(50)," +
                            "  credit_limit_check VARCHAR2(50)," +
                            "  position_limit_check VARCHAR2(50)," +
                            "  regulatory_check VARCHAR2(50)," +
                            "  locate_id VARCHAR2(50)," +
                            "  locate_required_flag NUMBER(1)," +
                            "  short_sale_exempt_flag NUMBER(1)," +
                            "  wash_sale_flag NUMBER(1)," +
                            // Trading flags
                            "  algorithmic_trading_flag NUMBER(1)," +
                            "  high_frequency_trading_flag NUMBER(1)," +
                            "  dark_pool_flag NUMBER(1)," +
                            "  cross_trading_flag NUMBER(1)," +
                            "  internalization_flag NUMBER(1)," +
                            "  market_maker_flag NUMBER(1)," +
                            "  proprietary_trading_flag NUMBER(1)," +
                            "  employee_account_flag NUMBER(1)," +
                            "  institutional_account_flag NUMBER(1)," +
                            "  large_trader_flag NUMBER(1)," +
                            "  pattern_day_trader_flag NUMBER(1)," +
                            "  oats_reportable NUMBER(1)," +
                            // Performance metrics
                            "  fill_rate NUMBER(19,2)," +
                            "  slippage NUMBER(19,2)," +
                            "  market_impact NUMBER(19,2)," +
                            "  implementation_shortfall NUMBER(19,2)," +
                            "  timing_cost NUMBER(19,2)," +
                            "  opportunity_cost NUMBER(19,2)," +
                            "  order_aggressiveness NUMBER(19,2)," +
                            "  participation_rate NUMBER(19,2)," +
                            "  arrival_price NUMBER(19,2)," +
                            "  decision_price NUMBER(19,2)," +
                            "  benchmark_price NUMBER(19,2)," +
                            // Market conditions
                            "  market_conditions VARCHAR2(50)," +
                            "  order_latency_ms NUMBER(10,0)," +
                            "  clearing_firm VARCHAR2(100)," +
                            "  clearing_account VARCHAR2(100)," +
                            "  contra_broker VARCHAR2(100)," +
                            // Historical analytics
                            "  orders_count_7d NUMBER(10,0)," +
                            "  orders_count_30d NUMBER(10,0)," +
                            "  total_volume_7d NUMBER(10,0)," +
                            "  total_volume_30d NUMBER(10,0)," +
                            "  avg_order_size_7d NUMBER(19,2)," +
                            "  avg_order_size_30d NUMBER(19,2)," +
                            "  success_rate_7d NUMBER(19,2)," +
                            "  success_rate_30d NUMBER(19,2)," +
                            // Risk and fraud fields
                            "  is_fraud NUMBER(1)," +
                            "  fraud_score NUMBER(19,2)," +
                            "  fraud_type VARCHAR2(50)," +
                            "  velocity_score NUMBER(19,2)," +
                            "  behavioral_risk_score NUMBER(19,2)," +
                            "  transaction_pattern_score NUMBER(19,2)," +
                            "  account_takeover_risk_score NUMBER(19,2)," +
                            "  geo_anomaly_flag NUMBER(1)," +
                            "  multiple_login_flag NUMBER(1)," +
                            "  high_risk_ip_flag NUMBER(1)," +
                            "  chargeback_history_flag NUMBER(1)," +
                            "  previous_fraud_flag NUMBER(1)," +
                            "  is_international NUMBER(1)," +
                            "  cross_border_flag NUMBER(1)," +
                            "  high_risk_country_flag NUMBER(1)," +
                            // IP and location fields
                            "  ip_address VARCHAR2(45)," +
                            "  ip_geolocation_country VARCHAR2(10)," +
                            "  ip_geolocation_state VARCHAR2(10)," +
                            "  ip_geolocation_city VARCHAR2(100)," +
                            "  ip_geolocation_zip VARCHAR2(20)," +
                            "  ip_geolocation_latitude NUMBER(10,6)," +
                            "  ip_geolocation_longitude NUMBER(10,6)," +
                            "  vpn_usage_flag NUMBER(1)," +
                            "  proxy_usage_flag NUMBER(1)," +
                            "  tor_usage_flag NUMBER(1)" +
                            ")",
                    tableName);
        } else {
            return String.format(
                    "CREATE TABLE IF NOT EXISTS %s (" +
                    // Core order fields
                            "  order_id VARCHAR(255) PRIMARY KEY," +
                            "  parent_order_id VARCHAR(255)," +
                            "  client_order_id VARCHAR(255)," +
                            "  order_type VARCHAR(50)," +
                            "  order_side VARCHAR(50)," +
                            "  order_status VARCHAR(50)," +
                            "  time_in_force VARCHAR(50)," +
                            "  timestamp VARCHAR(50)," +
                            "  order_date VARCHAR(20)," +
                            "  order_time VARCHAR(20)," +
                            "  order_timezone VARCHAR(50)," +
                            "  quantity INTEGER," +
                            "  filled_quantity INTEGER," +
                            "  remaining_quantity INTEGER," +
                            "  disclosed_quantity INTEGER," +
                            "  minimum_quantity INTEGER," +
                            // Security fields
                            "  security_id VARCHAR(50)," +
                            "  symbol VARCHAR(20)," +
                            "  security_type VARCHAR(50)," +
                            "  security_name VARCHAR(255)," +
                            "  cusip VARCHAR(20)," +
                            "  isin VARCHAR(20)," +
                            "  sedol VARCHAR(20)," +
                            "  exchange VARCHAR(50)," +
                            "  primary_exchange VARCHAR(50)," +
                            "  currency VARCHAR(10)," +
                            "  country_of_issue VARCHAR(10)," +
                            "  sector VARCHAR(100)," +
                            "  industry VARCHAR(100)," +
                            "  market_cap_category VARCHAR(50)," +
                            "  underlying_symbol VARCHAR(20)," +
                            "  option_type VARCHAR(10)," +
                            "  strike_price DECIMAL(19,2)," +
                            "  expiration_date VARCHAR(20)," +
                            "  days_to_expiration INTEGER," +
                            // Customer and account fields
                            "  customer_id VARCHAR(255)," +
                            "  customer_uuid VARCHAR(36)," +
                            "  customer_age INTEGER," +
                            "  customer_gender VARCHAR(20)," +
                            "  customer_income INTEGER," +
                            "  customer_income_range VARCHAR(50)," +
                            "  customer_account_tenure_years INTEGER," +
                            "  customer_education_level VARCHAR(50)," +
                            "  customer_employment_status VARCHAR(50)," +
                            "  customer_kyc_status VARCHAR(20)," +
                            "  customer_loyalty_points INTEGER," +
                            "  customer_loyalty_tier VARCHAR(20)," +
                            "  customer_marital_status VARCHAR(20)," +
                            "  customer_marketing_opt_in BOOLEAN," +
                            "  customer_residence_city VARCHAR(100)," +
                            "  customer_residence_country VARCHAR(10)," +
                            "  customer_residence_state VARCHAR(10)," +
                            "  customer_residence_zip VARCHAR(20)," +
                            "  customer_risk_category VARCHAR(20)," +
                            "  customer_segment VARCHAR(50)," +
                            "  customer_vip_flag BOOLEAN," +
                            "  account_id VARCHAR(255)," +
                            "  account_type VARCHAR(50)," +
                            "  account_name VARCHAR(255)," +
                            "  account_status VARCHAR(50)," +
                            "  account_balance DECIMAL(19,2)," +
                            "  account_equity DECIMAL(19,2)," +
                            "  buying_power DECIMAL(19,2)," +
                            "  day_trading_buying_power DECIMAL(19,2)," +
                            "  margin_balance DECIMAL(19,2)," +
                            "  net_liquidation_value DECIMAL(19,2)," +
                            // Pricing and market data fields
                            "  price DECIMAL(19,2)," +
                            "  stop_price DECIMAL(19,2)," +
                            "  limit_price DECIMAL(19,2)," +
                            "  average_fill_price DECIMAL(19,2)," +
                            "  last_fill_price DECIMAL(19,2)," +
                            "  last_fill_quantity INTEGER," +
                            "  total_fill_value DECIMAL(19,2)," +
                            "  bid_price DECIMAL(19,2)," +
                            "  ask_price DECIMAL(19,2)," +
                            "  bid_size INTEGER," +
                            "  ask_size INTEGER," +
                            "  last_trade_price DECIMAL(19,2)," +
                            "  last_trade_size INTEGER," +
                            "  open_price DECIMAL(19,2)," +
                            "  high_price DECIMAL(19,2)," +
                            "  low_price DECIMAL(19,2)," +
                            "  close_price DECIMAL(19,2)," +
                            "  previous_close DECIMAL(19,2)," +
                            "  price_change DECIMAL(19,2)," +
                            "  price_change_percent DECIMAL(19,2)," +
                            "  volume INTEGER," +
                            "  vwap DECIMAL(19,2)," +
                            "  volatility DECIMAL(19,2)," +
                            "  beta DECIMAL(19,2)," +
                            // Execution and trading fields
                            "  execution_id VARCHAR(255)," +
                            "  execution_venue VARCHAR(100)," +
                            "  execution_instructions VARCHAR(500)," +
                            "  order_handling_instructions TEXT," +
                            "  routing_destination VARCHAR(100)," +
                            "  best_execution_venue VARCHAR(100)," +
                            "  liquidity_indicator VARCHAR(20)," +
                            "  order_capacity VARCHAR(20)," +
                            "  trade_id VARCHAR(255)," +
                            "  regulatory_transaction_id VARCHAR(255)," +
                            "  cat_reporter_id VARCHAR(50)," +
                            // Fees and settlement
                            "  commission DECIMAL(19,2)," +
                            "  sec_fee DECIMAL(19,2)," +
                            "  taf_fee DECIMAL(19,2)," +
                            "  other_fees DECIMAL(19,2)," +
                            "  settlement_amount DECIMAL(19,2)," +
                            "  net_settlement_amount DECIMAL(19,2)," +
                            "  settlement_currency VARCHAR(10)," +
                            "  settlement_date VARCHAR(20)," +
                            "  accrued_interest DECIMAL(19,2)," +
                            // Risk and compliance fields
                            "  pre_trade_risk_check VARCHAR(50)," +
                            "  post_trade_risk_check VARCHAR(50)," +
                            "  credit_limit_check VARCHAR(50)," +
                            "  position_limit_check VARCHAR(50)," +
                            "  regulatory_check VARCHAR(50)," +
                            "  locate_id VARCHAR(50)," +
                            "  locate_required_flag BOOLEAN," +
                            "  short_sale_exempt_flag BOOLEAN," +
                            "  wash_sale_flag BOOLEAN," +
                            // Trading flags
                            "  algorithmic_trading_flag BOOLEAN," +
                            "  high_frequency_trading_flag BOOLEAN," +
                            "  dark_pool_flag BOOLEAN," +
                            "  cross_trading_flag BOOLEAN," +
                            "  internalization_flag BOOLEAN," +
                            "  market_maker_flag BOOLEAN," +
                            "  proprietary_trading_flag BOOLEAN," +
                            "  employee_account_flag BOOLEAN," +
                            "  institutional_account_flag BOOLEAN," +
                            "  large_trader_flag BOOLEAN," +
                            "  pattern_day_trader_flag BOOLEAN," +
                            "  oats_reportable BOOLEAN," +
                            // Performance metrics
                            "  fill_rate DECIMAL(19,2)," +
                            "  slippage DECIMAL(19,2)," +
                            "  market_impact DECIMAL(19,2)," +
                            "  implementation_shortfall DECIMAL(19,2)," +
                            "  timing_cost DECIMAL(19,2)," +
                            "  opportunity_cost DECIMAL(19,2)," +
                            "  order_aggressiveness DECIMAL(19,2)," +
                            "  participation_rate DECIMAL(19,2)," +
                            "  arrival_price DECIMAL(19,2)," +
                            "  decision_price DECIMAL(19,2)," +
                            "  benchmark_price DECIMAL(19,2)," +
                            // Market conditions
                            "  market_conditions VARCHAR(50)," +
                            "  order_latency_ms INTEGER," +
                            "  clearing_firm VARCHAR(100)," +
                            "  clearing_account VARCHAR(100)," +
                            "  contra_broker VARCHAR(100)," +
                            // Historical analytics
                            "  orders_count_7d INTEGER," +
                            "  orders_count_30d INTEGER," +
                            "  total_volume_7d INTEGER," +
                            "  total_volume_30d INTEGER," +
                            "  avg_order_size_7d DECIMAL(19,2)," +
                            "  avg_order_size_30d DECIMAL(19,2)," +
                            "  success_rate_7d DECIMAL(19,2)," +
                            "  success_rate_30d DECIMAL(19,2)," +
                            // Risk and fraud fields
                            "  is_fraud BOOLEAN," +
                            "  fraud_score DECIMAL(19,2)," +
                            "  fraud_type VARCHAR(50)," +
                            "  velocity_score DECIMAL(19,2)," +
                            "  behavioral_risk_score DECIMAL(19,2)," +
                            "  transaction_pattern_score DECIMAL(19,2)," +
                            "  account_takeover_risk_score DECIMAL(19,2)," +
                            "  geo_anomaly_flag BOOLEAN," +
                            "  multiple_login_flag BOOLEAN," +
                            "  high_risk_ip_flag BOOLEAN," +
                            "  chargeback_history_flag BOOLEAN," +
                            "  previous_fraud_flag BOOLEAN," +
                            "  is_international BOOLEAN," +
                            "  cross_border_flag BOOLEAN," +
                            "  high_risk_country_flag BOOLEAN," +
                            // IP and location fields
                            "  ip_address VARCHAR(45)," +
                            "  ip_geolocation_country VARCHAR(10)," +
                            "  ip_geolocation_state VARCHAR(10)," +
                            "  ip_geolocation_city VARCHAR(100)," +
                            "  ip_geolocation_zip VARCHAR(20)," +
                            "  ip_geolocation_latitude DECIMAL(10,6)," +
                            "  ip_geolocation_longitude DECIMAL(10,6)," +
                            "  vpn_usage_flag BOOLEAN," +
                            "  proxy_usage_flag BOOLEAN," +
                            "  tor_usage_flag BOOLEAN" +
                            ")",
                    tableName);
        }
    }

    /**
     * Write a single transaction to the database
     */
    @Override
    public boolean writeTransaction(Map<String, Object> transaction) {
        try {
            // Build a dynamic SQL insert statement based on the transaction fields
            StringBuilder sqlBuilder = new StringBuilder();
            sqlBuilder.append("INSERT INTO ").append(tableName).append(" (");

            // Add column names
            StringBuilder valuesBuilder = new StringBuilder();
            valuesBuilder.append("VALUES (");

            boolean first = true;
            for (String key : transaction.keySet()) {
                if (!first) {
                    sqlBuilder.append(", ");
                    valuesBuilder.append(", ");
                }
                sqlBuilder.append(key);
                valuesBuilder.append("?");
                first = false;
            }

            sqlBuilder.append(") ").append(valuesBuilder.append(")"));

            // Prepare and execute the statement
            try (PreparedStatement preparedStatement = connection.prepareStatement(sqlBuilder.toString())) {
                int paramIndex = 1;
                for (String key : transaction.keySet()) {
                    Object value = transaction.get(key);
                    preparedStatement.setObject(paramIndex++, value);
                }

                int rowsAffected = preparedStatement.executeUpdate();
                connection.commit();

                if (rowsAffected > 0) {
                    recordsWritten.incrementAndGet();
                    return true;
                }
                return false;
            }
        } catch (SQLException e) {
            try {
                connection.rollback();
            } catch (SQLException rollbackEx) {
                logger.error("[{}] Failed to rollback transaction", name, rollbackEx);
            }
            logger.error("[{}] Failed to write transaction to database", name, e);
            return false;
        }
    }

    @Override
    public int getRecordsWritten() {
        return recordsWritten.get();
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public void close() {
        if (connection != null) {
            try {
                connection.close();
                logger.info("[{}] Database connection closed", name);
            } catch (SQLException e) {
                logger.error("[{}] Failed to close database connection", name, e);
            }
        }
    }
}