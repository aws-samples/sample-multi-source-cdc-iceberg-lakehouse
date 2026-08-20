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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.Logger;

import com.amazonaws.services.secretsmanager.AWSSecretsManager;
import com.amazonaws.services.secretsmanager.AWSSecretsManagerClientBuilder;
import com.amazonaws.services.secretsmanager.model.GetSecretValueRequest;
import com.amazonaws.services.secretsmanager.model.GetSecretValueResult;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Writes financial transaction data to a relational database using JDBC
 * with connection details retrieved from AWS Secrets Manager
 */
public class DatabaseFinancialTransactionWriter implements DataWriter {
    private static final Logger logger = LoggerFactory.getLogger(DatabaseFinancialTransactionWriter.class);
    private static final ObjectMapper objectMapper = new ObjectMapper();

    private final String secretName;
    private final String region;
    private final String tableName;
    private final boolean createTableIfNotExists;
    private Connection connection;
    private final AtomicInteger recordsWritten = new AtomicInteger(0);
    private final String name;

    /**
     * Constructor for DatabaseFinancialTransactionWriter
     * 
     * @param name                   Descriptive name for this writer (e.g., "Aurora
     *                               PostgreSQL")
     * @param secretName             Name of the secret in AWS Secrets Manager
     *                               containing database connection details
     * @param region                 AWS region where the secret is stored
     * @param tableName              Name of the table to write to
     * @param createTableIfNotExists Whether to create the table if it doesn't exist
     */
    public DatabaseFinancialTransactionWriter(String name, String secretName, String region, String tableName,
            boolean createTableIfNotExists) {
        this.name = name;
        this.secretName = secretName;
        this.region = region;
        this.tableName = tableName;
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
                // Oracle XE service name format - use lowercase service name
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
            // Get database metadata to detect engine type
            String databaseProductName = connection.getMetaData().getDatabaseProductName().toLowerCase();

            String checkTableSQL;
            if (databaseProductName.contains("oracle")) {
                // Oracle query to check if table exists
                checkTableSQL = String.format(
                        "SELECT COUNT(*) FROM user_tables WHERE table_name = '%s'",
                        tableName.toUpperCase());
            } else {
                // PostgreSQL and other databases
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
     * Create the financial transactions table if it doesn't exist
     */
    private void createTableIfNotExists() throws SQLException {
        logger.info("[{}] Checking if table exists: {}", name, tableName);

        if (tableExists()) {
            logger.info("[{}] Table already exists: {}", name, tableName);
            return;
        }

        logger.info("[{}] Creating table: {}", name, tableName);

        // Get database metadata to determine SQL dialect
        String databaseProductName = connection.getMetaData().getDatabaseProductName().toLowerCase();
        boolean isOracle = databaseProductName.contains("oracle");

        // Create a comprehensive table schema for financial transactions
        // Using VARCHAR for date and timestamp fields to avoid type conversion issues
        String createTableSQL;

        if (isOracle) {
            // Oracle-specific table creation (no IF NOT EXISTS support)
            createTableSQL = String.format(
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
                            "  transaction_description CLOB," +
                            "  transaction_category VARCHAR2(50)," +
                            "  transaction_subcategory VARCHAR2(50)," +
                            "  customer_id VARCHAR2(255)," +
                            "  customer_uuid VARCHAR2(36)," +
                            "  customer_age NUMBER," +
                            "  customer_gender VARCHAR2(20)," +
                            "  customer_income NUMBER," +
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
                            "  customer_account_tenure_years NUMBER," +
                            "  customer_loyalty_points NUMBER," +
                            "  merchant_id VARCHAR2(255)," +
                            "  merchant_name VARCHAR2(255)," +
                            "  merchant_category_code VARCHAR2(10)," +
                            "  merchant_category VARCHAR2(50)," +
                            "  merchant_subcategory VARCHAR2(50)," +
                            "  merchant_rating NUMBER(5,2)," +
                            "  merchant_country VARCHAR2(10)," +
                            "  merchant_state VARCHAR2(10)," +
                            "  merchant_city VARCHAR2(100)," +
                            "  merchant_zip VARCHAR2(20)," +
                            "  merchant_average_txn_value NUMBER(19,2)," +
                            "  merchant_chargeback_rate NUMBER(10,6)," +
                            "  merchant_high_risk_flag NUMBER(1) CHECK (merchant_high_risk_flag IN (0,1))," +
                            "  payment_method VARCHAR2(50)," +
                            "  payment_method_type VARCHAR2(50)," +
                            "  payment_method_subtype VARCHAR2(50)," +
                            "  payment_card_last_four VARCHAR2(4)," +
                            "  payment_card_expiry VARCHAR2(10)," +
                            "  payment_card_issuer VARCHAR2(100)," +
                            "  payment_card_country VARCHAR2(10)," +
                            "  payment_card_funding_type VARCHAR2(20)," +
                            "  payment_card_level VARCHAR2(20)," +
                            "  payment_card_bin VARCHAR2(10)," +
                            "  ip_address VARCHAR2(50)," +
                            "  ip_geolocation_country VARCHAR2(10)," +
                            "  ip_geolocation_state VARCHAR2(10)," +
                            "  ip_geolocation_city VARCHAR2(100)," +
                            "  ip_geolocation_zip VARCHAR2(20)," +
                            "  ip_geolocation_latitude NUMBER(10,6)," +
                            "  ip_geolocation_longitude NUMBER(10,6)," +
                            "  vpn_usage_flag NUMBER(1) CHECK (vpn_usage_flag IN (0,1))," +
                            "  proxy_usage_flag NUMBER(1) CHECK (proxy_usage_flag IN (0,1))," +
                            "  tor_usage_flag NUMBER(1) CHECK (tor_usage_flag IN (0,1))," +
                            "  is_fraud NUMBER(1) CHECK (is_fraud IN (0,1))," +
                            "  fraud_score NUMBER(10,6)," +
                            "  fraud_type VARCHAR2(50)," +
                            "  velocity_score NUMBER(10,6)," +
                            "  behavioral_risk_score NUMBER(10,6)," +
                            "  transaction_pattern_score NUMBER(10,6)," +
                            "  geo_anomaly_flag NUMBER(1) CHECK (geo_anomaly_flag IN (0,1))," +
                            "  multiple_login_flag NUMBER(1) CHECK (multiple_login_flag IN (0,1))," +
                            "  high_risk_ip_flag NUMBER(1) CHECK (high_risk_ip_flag IN (0,1))," +
                            "  account_takeover_risk_score NUMBER(10,6)," +
                            "  chargeback_history_flag NUMBER(1) CHECK (chargeback_history_flag IN (0,1))," +
                            "  previous_fraud_flag NUMBER(1) CHECK (previous_fraud_flag IN (0,1))," +
                            "  is_international NUMBER(1) CHECK (is_international IN (0,1))," +
                            "  cross_border_flag NUMBER(1) CHECK (cross_border_flag IN (0,1))," +
                            "  high_risk_country_flag NUMBER(1) CHECK (high_risk_country_flag IN (0,1))," +
                            "  transaction_count_7d NUMBER," +
                            "  transaction_amount_7d NUMBER(19,2)," +
                            "  avg_transaction_amount_7d NUMBER(19,2)," +
                            "  max_transaction_amount_7d NUMBER(19,2)," +
                            "  transaction_count_30d NUMBER," +
                            "  transaction_amount_30d NUMBER(19,2)," +
                            "  avg_transaction_amount_30d NUMBER(19,2)," +
                            "  max_transaction_amount_30d NUMBER(19,2)," +
                            "  transaction_count_90d NUMBER," +
                            "  transaction_amount_90d NUMBER(19,2)," +
                            "  transaction_count_365d NUMBER," +
                            "  transaction_amount_365d NUMBER(19,2)," +
                            "  online_transaction_ratio_30d NUMBER(10,6)," +
                            "  average_daily_transactions_30d NUMBER(10,6)," +
                            "  days_active_last_30d NUMBER" +
                            ")",
                    tableName);
        } else {
            // PostgreSQL and other databases - original format
            createTableSQL = String.format(
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
                            "  merchant_id VARCHAR(255)," +
                            "  merchant_name VARCHAR(255)," +
                            "  merchant_category_code VARCHAR(10)," +
                            "  merchant_category VARCHAR(50)," +
                            "  merchant_subcategory VARCHAR(50)," +
                            "  merchant_rating DECIMAL(5,2)," +
                            "  merchant_country VARCHAR(10)," +
                            "  merchant_state VARCHAR(10)," +
                            "  merchant_city VARCHAR(100)," +
                            "  merchant_zip VARCHAR(20)," +
                            "  merchant_average_txn_value DECIMAL(19,2)," +
                            "  merchant_chargeback_rate DECIMAL(10,6)," +
                            "  merchant_high_risk_flag BOOLEAN," +
                            "  payment_method VARCHAR(50)," +
                            "  payment_method_type VARCHAR(50)," +
                            "  payment_method_subtype VARCHAR(50)," +
                            "  payment_card_last_four VARCHAR(4)," +
                            "  payment_card_expiry VARCHAR(10)," +
                            "  payment_card_issuer VARCHAR(100)," +
                            "  payment_card_country VARCHAR(10)," +
                            "  payment_card_funding_type VARCHAR(20)," +
                            "  payment_card_level VARCHAR(20)," +
                            "  payment_card_bin VARCHAR(10)," +
                            "  ip_address VARCHAR(50)," +
                            "  ip_geolocation_country VARCHAR(10)," +
                            "  ip_geolocation_state VARCHAR(10)," +
                            "  ip_geolocation_city VARCHAR(100)," +
                            "  ip_geolocation_zip VARCHAR(20)," +
                            "  ip_geolocation_latitude DECIMAL(10,6)," +
                            "  ip_geolocation_longitude DECIMAL(10,6)," +
                            "  vpn_usage_flag BOOLEAN," +
                            "  proxy_usage_flag BOOLEAN," +
                            "  tor_usage_flag BOOLEAN," +
                            "  is_fraud BOOLEAN," +
                            "  fraud_score DECIMAL(10,6)," +
                            "  fraud_type VARCHAR(50)," +
                            "  velocity_score DECIMAL(10,6)," +
                            "  behavioral_risk_score DECIMAL(10,6)," +
                            "  transaction_pattern_score DECIMAL(10,6)," +
                            "  geo_anomaly_flag BOOLEAN," +
                            "  multiple_login_flag BOOLEAN," +
                            "  high_risk_ip_flag BOOLEAN," +
                            "  account_takeover_risk_score DECIMAL(10,6)," +
                            "  chargeback_history_flag BOOLEAN," +
                            "  previous_fraud_flag BOOLEAN," +
                            "  is_international BOOLEAN," +
                            "  cross_border_flag BOOLEAN," +
                            "  high_risk_country_flag BOOLEAN," +
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
                            "  online_transaction_ratio_30d DECIMAL(10,6)," +
                            "  average_daily_transactions_30d DECIMAL(10,6)," +
                            "  days_active_last_30d INTEGER" +
                            ")",
                    tableName);
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
     * Write a single transaction to the database
     * 
     * @param transaction The transaction data to write
     * @return true if the write was successful, false otherwise
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

    /**
     * Get the number of records written to the database
     * 
     * @return Number of records written
     */
    @Override
    public int getRecordsWritten() {
        return recordsWritten.get();
    }

    /**
     * Get the name of this data writer
     * 
     * @return Name of the data writer
     */
    @Override
    public String getName() {
        return name;
    }

    /**
     * Close the database connection
     */
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
