// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.datagenerator;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

/**
 * Base class for transaction generators with common functionality
 */
public abstract class BaseTransactionGenerator {
    protected static final Random random = new Random();
    protected static final DateTimeFormatter ISO_DATE_TIME = DateTimeFormatter.ISO_DATE_TIME;
    protected static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    protected static final DateTimeFormatter TIME_FORMATTER = DateTimeFormatter.ofPattern("HH:mm:ss");

    // Common data arrays
    protected static final String[] GENDERS = { "Male", "Female", "Other", "Prefer not to say" };
    protected static final String[] MARITAL_STATUSES = { "Single", "Married", "Divorced", "Widowed", "Separated" };
    protected static final String[] EMPLOYMENT_STATUSES = { "Employed", "Self-Employed", "Unemployed", "Retired",
            "Student" };
    protected static final String[] EDUCATION_LEVELS = { "High School", "Associate's", "Bachelor's", "Master's",
            "Doctorate" };
    protected static final String[] RISK_CATEGORIES = { "Low", "Medium", "High" };
    protected static final String[] LOYALTY_TIERS = { "Bronze", "Silver", "Gold", "Platinum", "Diamond" };
    protected static final String[] CUSTOMER_SEGMENTS = { "Mass Market", "Mass Affluent", "Affluent",
            "High Net Worth" };
    protected static final String[] COUNTRIES = { "US", "CA", "GB", "DE", "FR", "JP", "AU" };
    protected static final String[] US_STATES = { "NY", "CA", "TX", "FL", "IL", "PA", "OH", "GA", "NC", "MI" };
    protected static final String[] US_CITIES = {
            "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia", "San Antonio", "San Diego"
    };

    /**
     * Generate a transaction with the specific implementation
     * 
     * @return Map containing the transaction data
     */
    public abstract Map<String, Object> generateTransaction();

    /**
     * Get the table name for this transaction type
     * 
     * @return Table name
     */
    public abstract String getTableName();

    /**
     * Populate common customer information
     */
    protected void populateCustomerInformation(Map<String, Object> transaction, String customerId) {
        String customerUuid = UUID.randomUUID().toString();
        int age = 18 + random.nextInt(68);
        String gender = random.nextDouble() < 0.49 ? "Male"
                : random.nextDouble() < 0.98 ? "Female" : random.nextDouble() < 0.5 ? "Other" : "Prefer not to say";

        int income = generateIncomeBasedOnAge(age);
        String incomeRange = generateIncomeRange(income);
        String maritalStatus = MARITAL_STATUSES[random.nextInt(MARITAL_STATUSES.length)];
        String country = random.nextDouble() < 0.85 ? "US" : COUNTRIES[random.nextInt(COUNTRIES.length)];
        String state = US_STATES[random.nextInt(US_STATES.length)];
        String city = US_CITIES[random.nextInt(US_CITIES.length)];
        String zip = String.format("%05d", random.nextInt(100000));

        transaction.put("customer_id", customerId);
        transaction.put("customer_uuid", customerUuid);
        transaction.put("customer_age", age);
        transaction.put("customer_gender", gender);
        transaction.put("customer_income", income);
        transaction.put("customer_income_range", incomeRange);
        transaction.put("customer_marital_status", maritalStatus);
        transaction.put("customer_residence_country", country);
        transaction.put("customer_residence_state", state);
        transaction.put("customer_residence_city", city);
        transaction.put("customer_residence_zip", zip);
        transaction.put("customer_kyc_status", random.nextDouble() < 0.95 ? "Verified" : "Pending");
        transaction.put("customer_employment_status", EMPLOYMENT_STATUSES[random.nextInt(EMPLOYMENT_STATUSES.length)]);
        transaction.put("customer_education_level", EDUCATION_LEVELS[random.nextInt(EDUCATION_LEVELS.length)]);
        transaction.put("customer_risk_category", RISK_CATEGORIES[random.nextInt(RISK_CATEGORIES.length)]);
        transaction.put("customer_vip_flag", income > 150000 || (income > 100000 && random.nextDouble() < 0.5));
        transaction.put("customer_loyalty_tier", LOYALTY_TIERS[random.nextInt(LOYALTY_TIERS.length)]);
        transaction.put("customer_marketing_opt_in", random.nextDouble() < 0.6);
        transaction.put("customer_segment", CUSTOMER_SEGMENTS[random.nextInt(CUSTOMER_SEGMENTS.length)]);
        transaction.put("customer_account_tenure_years", 1 + random.nextInt(20));
        transaction.put("customer_loyalty_points", random.nextInt(10000));
    }

    /**
     * Populate common location information
     */
    protected void populateLocationInformation(Map<String, Object> transaction) {
        transaction.put("ip_address", generateIpAddress());
        transaction.put("ip_geolocation_country", COUNTRIES[random.nextInt(COUNTRIES.length)]);
        transaction.put("ip_geolocation_state", US_STATES[random.nextInt(US_STATES.length)]);
        transaction.put("ip_geolocation_city", US_CITIES[random.nextInt(US_CITIES.length)]);
        transaction.put("ip_geolocation_zip", String.format("%05d", random.nextInt(100000)));
        transaction.put("ip_geolocation_latitude", 25.0 + random.nextDouble() * 25.0);
        transaction.put("ip_geolocation_longitude", -125.0 + random.nextDouble() * 50.0);
        transaction.put("vpn_usage_flag", random.nextDouble() < 0.1);
        transaction.put("proxy_usage_flag", random.nextDouble() < 0.05);
        transaction.put("tor_usage_flag", random.nextDouble() < 0.01);
    }

    /**
     * Populate common risk and fraud indicators
     */
    protected void populateRiskAndFraudIndicators(Map<String, Object> transaction) {
        boolean isFraud = random.nextDouble() < 0.02; // 2% fraud rate

        transaction.put("is_fraud", isFraud);
        transaction.put("fraud_score", isFraud ? 70.0 + random.nextDouble() * 30.0 : random.nextDouble() * 50.0);
        transaction.put("fraud_type", isFraud ? "STOLEN_CARD" : "NONE");
        transaction.put("velocity_score", random.nextDouble() * 100.0);
        transaction.put("behavioral_risk_score", random.nextDouble() * 100.0);
        transaction.put("transaction_pattern_score", random.nextDouble() * 100.0);
        transaction.put("geo_anomaly_flag", random.nextDouble() < 0.1);
        transaction.put("multiple_login_flag", random.nextDouble() < 0.2);
        transaction.put("high_risk_ip_flag", random.nextDouble() < 0.05);
        transaction.put("account_takeover_risk_score", random.nextDouble() * 100.0);
        transaction.put("chargeback_history_flag", random.nextDouble() < 0.03);
        transaction.put("previous_fraud_flag", random.nextDouble() < 0.01);
        transaction.put("is_international", random.nextDouble() < 0.15);
        transaction.put("cross_border_flag", random.nextDouble() < 0.1);
        transaction.put("high_risk_country_flag", random.nextDouble() < 0.05);
    }

    /**
     * Generate timestamp within the last 30 days
     */
    protected LocalDateTime generateTimestamp() {
        return LocalDateTime.now(ZoneOffset.UTC)
                .minusDays(random.nextInt(30))
                .minusHours(random.nextInt(24))
                .minusMinutes(random.nextInt(60))
                .minusSeconds(random.nextInt(60));
    }

    /**
     * Generate income based on age
     */
    protected int generateIncomeBasedOnAge(int age) {
        if (age < 25)
            return 30000 + random.nextInt(20000);
        if (age < 35)
            return 50000 + random.nextInt(30000);
        if (age < 45)
            return 70000 + random.nextInt(50000);
        if (age < 55)
            return 80000 + random.nextInt(70000);
        if (age < 65)
            return 70000 + random.nextInt(80000);
        return 50000 + random.nextInt(50000);
    }

    /**
     * Generate income range string
     */
    protected String generateIncomeRange(int income) {
        if (income < 25000)
            return "Under 25000";
        if (income < 50000)
            return "25000-50000";
        if (income < 75000)
            return "50000-75000";
        if (income < 100000)
            return "75000-100000";
        if (income < 150000)
            return "100000-150000";
        return "150000+";
    }

    /**
     * Generate IP address
     */
    protected String generateIpAddress() {
        return random.nextInt(256) + "." + random.nextInt(256) + "." +
                random.nextInt(256) + "." + random.nextInt(256);
    }

    /**
     * Round to two decimal places
     */
    protected double roundToTwoDecimals(double value) {
        BigDecimal bd = BigDecimal.valueOf(value);
        bd = bd.setScale(2, RoundingMode.HALF_UP);
        return bd.doubleValue();
    }
}
