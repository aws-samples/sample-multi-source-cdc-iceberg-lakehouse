// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.datagenerator;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Generates financial transaction data with 101 columns
 */
public class FinancialTransactionGenerator extends BaseTransactionGenerator {

    // Transaction types and categories
    private static final String[] TRANSACTION_TYPES = {
            "PURCHASE", "REFUND", "PAYMENT", "WITHDRAWAL", "DEPOSIT", "TRANSFER", "BILL_PAYMENT"
    };

    private static final String[] TRANSACTION_SUBTYPES = {
            "RETAIL", "ONLINE", "RECURRING", "INSTALLMENT", "CASH_ADVANCE", "ATM", "POS", "MOBILE"
    };

    private static final String[] TRANSACTION_STATUSES = {
            "COMPLETED", "PENDING", "DECLINED", "CANCELLED", "FAILED", "AUTHORIZED", "SETTLED"
    };

    private static final String[] TRANSACTION_CATEGORIES = {
            "SHOPPING", "DINING", "TRAVEL", "ENTERTAINMENT", "GROCERIES", "UTILITIES", "HEALTHCARE"
    };

    private static final Map<String, String[]> TRANSACTION_SUBCATEGORIES = new HashMap<String, String[]>() {
        {
            put("SHOPPING",
                    new String[] { "ELECTRONICS", "CLOTHING", "JEWELRY", "DEPARTMENT_STORE", "ONLINE_MARKETPLACE" });
            put("DINING", new String[] { "RESTAURANT", "FAST_FOOD", "CAFE", "BAR", "FOOD_DELIVERY" });
            put("TRAVEL", new String[] { "AIRLINE", "HOTEL", "CAR_RENTAL", "CRUISE", "TRAVEL_AGENCY" });
            put("ENTERTAINMENT", new String[] { "MOVIE", "CONCERT", "SPORTS_EVENT", "STREAMING_SERVICE", "GAMING" });
            put("GROCERIES", new String[] { "SUPERMARKET", "SPECIALTY_FOOD", "CONVENIENCE_STORE", "FARMERS_MARKET" });
            put("UTILITIES", new String[] { "ELECTRICITY", "WATER", "GAS", "INTERNET", "PHONE", "CABLE" });
            put("HEALTHCARE", new String[] { "DOCTOR", "HOSPITAL", "PHARMACY", "DENTAL", "VISION", "INSURANCE" });
        }
    };

    // Payment methods
    private static final String[] PAYMENT_METHODS = {
            "Credit Card", "Debit Card", "Bank Transfer", "Digital Wallet", "Mobile Payment"
    };

    private static final String[] PAYMENT_METHOD_TYPES = {
            "VISA", "MASTERCARD", "AMEX", "DISCOVER", "PAYPAL", "APPLE_PAY", "GOOGLE_PAY"
    };

    @Override
    public String getTableName() {
        return "financial_transactions";
    }

    /**
     * Generate a single financial transaction with ~200 columns
     * 
     * @return Map containing the transaction data
     */
    @Override
    public Map<String, Object> generateTransaction() {
        Map<String, Object> transaction = new HashMap<>();

        // Generate transaction ID
        String transactionId = "TXN" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        String customerId = "CUST" + String.format("%07d", random.nextInt(10000));
        String merchantId = "MCHT" + String.format("%07d", random.nextInt(1000));

        // 1. Core Transaction Details
        populateCoreTransactionDetails(transaction, transactionId);

        // 2. Customer Information
        populateCustomerInformation(transaction, customerId);

        // 3. Merchant Information
        populateMerchantInformation(transaction, merchantId);

        // 4. Payment Method Details
        populatePaymentMethodDetails(transaction);

        // 5. Location Information
        populateLocationInformation(transaction);

        // 6. Risk and Fraud Indicators
        populateRiskAndFraudIndicators(transaction);

        // 7. Transaction History Metrics
        populateTransactionHistoryMetrics(transaction);

        return transaction;
    }

    /**
     * Populate core transaction details
     */
    private void populateCoreTransactionDetails(Map<String, Object> transaction, String transactionId) {
        // Generate a timestamp within the last 30 days
        LocalDateTime timestamp = generateTimestamp();

        String transactionType = TRANSACTION_TYPES[random.nextInt(TRANSACTION_TYPES.length)];
        String transactionSubtype = TRANSACTION_SUBTYPES[random.nextInt(TRANSACTION_SUBTYPES.length)];
        String transactionStatus = TRANSACTION_STATUSES[random.nextInt(TRANSACTION_STATUSES.length)];
        String transactionCategory = TRANSACTION_CATEGORIES[random.nextInt(TRANSACTION_CATEGORIES.length)];
        String transactionSubcategory = TRANSACTION_SUBCATEGORIES.get(transactionCategory)[random
                .nextInt(TRANSACTION_SUBCATEGORIES.get(transactionCategory).length)];

        // Generate amount based on category
        double amount = generateAmountForCategory(transactionCategory);

        // Adjust amount for refunds
        if (transactionType.equals("REFUND")) {
            amount = -amount;
        }

        transaction.put("transaction_id", transactionId);
        transaction.put("transaction_reference_id",
                "REF" + UUID.randomUUID().toString().replace("-", "").substring(0, 12));
        transaction.put("transaction_type", transactionType);
        transaction.put("transaction_subtype", transactionSubtype);
        transaction.put("timestamp", timestamp.format(ISO_DATE_TIME) + "Z");
        transaction.put("transaction_date", timestamp.format(DATE_FORMATTER));
        transaction.put("transaction_time", timestamp.format(TIME_FORMATTER));
        transaction.put("transaction_timezone", "America/New_York");
        transaction.put("transaction_amount", roundToTwoDecimals(amount));
        transaction.put("transaction_original_amount", roundToTwoDecimals(amount));

        // Currency - mostly USD with some international
        String currency = random.nextDouble() < 0.9 ? "USD"
                : random.nextDouble() < 0.5 ? "EUR" : random.nextDouble() < 0.5 ? "GBP" : "CAD";

        transaction.put("currency", currency);
        transaction.put("original_currency", currency);
        transaction.put("exchange_rate", currency.equals("USD") ? 1.0 : generateExchangeRate(currency));
        transaction.put("transaction_status", transactionStatus);
        transaction.put("transaction_description",
                generateTransactionDescription(transactionCategory, transactionSubcategory));
        transaction.put("transaction_category", transactionCategory);
        transaction.put("transaction_subcategory", transactionSubcategory);
    }

    /**
     * Populate merchant information
     */
    private void populateMerchantInformation(Map<String, Object> transaction, String merchantId) {
        String merchantCategory = TRANSACTION_CATEGORIES[random.nextInt(TRANSACTION_CATEGORIES.length)];
        String merchantSubcategory = TRANSACTION_SUBCATEGORIES.get(merchantCategory)[random
                .nextInt(TRANSACTION_SUBCATEGORIES.get(merchantCategory).length)];

        transaction.put("merchant_id", merchantId);
        transaction.put("merchant_name", generateMerchantName(merchantCategory, merchantSubcategory));
        transaction.put("merchant_category_code", String.format("%04d", random.nextInt(10000)));
        transaction.put("merchant_category", merchantCategory);
        transaction.put("merchant_subcategory", merchantSubcategory);
        transaction.put("merchant_rating", 1.0 + random.nextDouble() * 4.0);
        transaction.put("merchant_country", COUNTRIES[random.nextInt(COUNTRIES.length)]);
        transaction.put("merchant_state", US_STATES[random.nextInt(US_STATES.length)]);
        transaction.put("merchant_city", US_CITIES[random.nextInt(US_CITIES.length)]);
        transaction.put("merchant_zip", String.format("%05d", random.nextInt(100000)));
        transaction.put("merchant_average_txn_value", 50 + random.nextDouble() * 950);
        transaction.put("merchant_chargeback_rate", random.nextDouble() * 0.05);
        transaction.put("merchant_high_risk_flag", random.nextDouble() < 0.1);
    }

    /**
     * Populate payment method details
     */
    private void populatePaymentMethodDetails(Map<String, Object> transaction) {
        String paymentMethod = PAYMENT_METHODS[random.nextInt(PAYMENT_METHODS.length)];
        String paymentMethodType = PAYMENT_METHOD_TYPES[random.nextInt(PAYMENT_METHOD_TYPES.length)];

        transaction.put("payment_method", paymentMethod);
        transaction.put("payment_method_type", paymentMethodType);
        transaction.put("payment_method_subtype",
                paymentMethodType + (random.nextBoolean() ? " SIGNATURE" : " STANDARD"));
        transaction.put("payment_card_last_four", String.format("%04d", random.nextInt(10000)));
        transaction.put("payment_card_expiry",
                String.format("%02d/%02d", random.nextInt(12) + 1, random.nextInt(5) + 25));
        transaction.put("payment_card_issuer", "Bank " + (char) ('A' + random.nextInt(26)));
        transaction.put("payment_card_country", COUNTRIES[random.nextInt(COUNTRIES.length)]);
        transaction.put("payment_card_funding_type", random.nextBoolean() ? "CREDIT" : "DEBIT");
        transaction.put("payment_card_level", random.nextBoolean() ? "STANDARD" : "PREMIUM");
        transaction.put("payment_card_bin", String.format("%06d", random.nextInt(1000000)));
    }

    /**
     * Populate transaction history metrics
     */
    private void populateTransactionHistoryMetrics(Map<String, Object> transaction) {
        int txCount7d = random.nextInt(30);
        double txAmount7d = txCount7d * (50 + random.nextDouble() * 150);

        int txCount30d = txCount7d + random.nextInt(70);
        double txAmount30d = txAmount7d + (txCount30d - txCount7d) * (50 + random.nextDouble() * 150);

        int txCount90d = txCount30d + random.nextInt(150);
        double txAmount90d = txAmount30d + (txCount90d - txCount30d) * (50 + random.nextDouble() * 150);

        int txCount365d = txCount90d + random.nextInt(700);
        double txAmount365d = txAmount90d + (txCount365d - txCount90d) * (50 + random.nextDouble() * 150);

        transaction.put("transaction_count_7d", txCount7d);
        transaction.put("transaction_amount_7d", roundToTwoDecimals(txAmount7d));
        transaction.put("avg_transaction_amount_7d", txCount7d > 0 ? roundToTwoDecimals(txAmount7d / txCount7d) : 0.0);
        transaction.put("max_transaction_amount_7d", roundToTwoDecimals(100 + random.nextDouble() * 900));

        transaction.put("transaction_count_30d", txCount30d);
        transaction.put("transaction_amount_30d", roundToTwoDecimals(txAmount30d));
        transaction.put("avg_transaction_amount_30d",
                txCount30d > 0 ? roundToTwoDecimals(txAmount30d / txCount30d) : 0.0);
        transaction.put("max_transaction_amount_30d", roundToTwoDecimals(200 + random.nextDouble() * 2300));

        transaction.put("transaction_count_90d", txCount90d);
        transaction.put("transaction_amount_90d", roundToTwoDecimals(txAmount90d));

        transaction.put("transaction_count_365d", txCount365d);
        transaction.put("transaction_amount_365d", roundToTwoDecimals(txAmount365d));

        transaction.put("online_transaction_ratio_30d", random.nextDouble());
        transaction.put("average_daily_transactions_30d", roundToTwoDecimals(txCount30d / 30.0));
        transaction.put("days_active_last_30d", 10 + random.nextInt(21));
    }

    // Helper methods

    private double generateAmountForCategory(String category) {
        switch (category) {
            case "SHOPPING":
                return 50 + random.nextDouble() * 450;
            case "DINING":
                return 20 + random.nextDouble() * 180;
            case "TRAVEL":
                return 100 + random.nextDouble() * 1900;
            case "ENTERTAINMENT":
                return 20 + random.nextDouble() * 280;
            case "GROCERIES":
                return 30 + random.nextDouble() * 270;
            case "UTILITIES":
                return 50 + random.nextDouble() * 350;
            case "HEALTHCARE":
                return 50 + random.nextDouble() * 950;
            default:
                return 10 + random.nextDouble() * 990;
        }
    }

    private double generateExchangeRate(String currency) {
        switch (currency) {
            case "EUR":
                return 0.85 + (random.nextDouble() * 0.1 - 0.05);
            case "GBP":
                return 0.75 + (random.nextDouble() * 0.1 - 0.05);
            case "CAD":
                return 1.25 + (random.nextDouble() * 0.1 - 0.05);
            default:
                return 1.0;
        }
    }

    private String generateTransactionDescription(String category, String subcategory) {
        String[] prefixes = { "Payment to", "Purchase at", "Transaction with", "Service from" };
        String prefix = prefixes[random.nextInt(prefixes.length)];
        return prefix + " " + generateMerchantName(category, subcategory);
    }

    private String generateMerchantName(String category, String subcategory) {
        String[] adjectives = { "Global", "National", "Premier", "Elite", "Value", "Quality", "Discount", "Luxury" };
        String adjective = adjectives[random.nextInt(adjectives.length)];

        return adjective + " " + subcategory.replace("_", " ");
    }
}
