// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.datagenerator;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Generates brokerage transaction data with 180 columns
 */
public class BrokerageTransactionGenerator extends BaseTransactionGenerator {

        // Order types
        private static final String[] ORDER_TYPES = {
                        "MARKET", "LIMIT", "STOP", "STOP_LIMIT", "TRAILING_STOP", "BRACKET", "OCO", "ICEBERG"
        };

        // Order sides
        private static final String[] ORDER_SIDES = {
                        "BUY", "SELL", "BUY_TO_COVER", "SELL_SHORT"
        };

        // Order statuses
        private static final String[] ORDER_STATUSES = {
                        "NEW", "PARTIALLY_FILLED", "FILLED", "CANCELLED", "REJECTED", "EXPIRED", "PENDING_CANCEL",
                        "PENDING_REPLACE"
        };

        // Time in force
        private static final String[] TIME_IN_FORCE = {
                        "DAY", "GTC", "IOC", "FOK", "GTD", "ATC", "ATO"
        };

        // Security types
        private static final String[] SECURITY_TYPES = {
                        "STOCK", "ETF", "OPTION", "BOND", "MUTUAL_FUND", "FUTURES", "FOREX", "CRYPTO"
        };

        // Exchanges
        private static final String[] EXCHANGES = {
                        "NYSE", "NASDAQ", "AMEX", "BATS", "IEX", "ARCA", "CBOE", "CME", "ICE"
        };

        // Execution instructions
        private static final String[] EXECUTION_INSTRUCTIONS = {
                        "ALL_OR_NONE", "FILL_OR_KILL", "IMMEDIATE_OR_CANCEL", "GOOD_TILL_CANCELED", "DISCRETIONARY",
                        "MINIMUM_QUANTITY"
        };

        // Account types
        private static final String[] ACCOUNT_TYPES = {
                        "INDIVIDUAL", "JOINT", "IRA", "ROTH_IRA", "401K", "TRUST", "CORPORATE", "MARGIN", "CASH"
        };

        // Order routing destinations
        private static final String[] ROUTING_DESTINATIONS = {
                        "SMART", "ISLAND", "ARCA", "NASDAQ", "NYSE", "BATS", "IEX", "EDGX", "EDGA"
        };

        // Popular stock symbols
        private static final String[] STOCK_SYMBOLS = {
                        "AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "META", "NVDA", "NFLX", "ORCL", "CRM",
                        "UBER", "LYFT", "ZOOM", "SHOP", "SQ", "PYPL", "ADBE", "INTC", "AMD", "QCOM",
                        "JPM", "BAC", "WFC", "GS", "MS", "C", "USB", "PNC", "TFC", "COF",
                        "JNJ", "PFE", "UNH", "CVS", "ABBV", "MRK", "BMY", "GILD", "AMGN", "BIIB",
                        "XOM", "CVX", "COP", "EOG", "SLB", "HAL", "OXY", "MPC", "VLO", "PSX"
        };

        // ETF symbols
        private static final String[] ETF_SYMBOLS = {
                        "SPY", "QQQ", "IWM", "VTI", "VOO", "VEA", "VWO", "AGG", "BND", "TLT",
                        "GLD", "SLV", "USO", "XLE", "XLF", "XLK", "XLV", "XLI", "XLP", "XLU"
        };

        @Override
        public String getTableName() {
                return "brokerage_transactions";
        }

        @Override
        public Map<String, Object> generateTransaction() {
                Map<String, Object> transaction = new HashMap<>();

                // Generate IDs
                String orderId = "ORD" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
                String customerId = "CUST" + String.format("%07d", random.nextInt(10000));
                String accountId = "ACCT" + String.format("%08d", random.nextInt(100000));

                // 1. Core Order Details
                populateCoreOrderDetails(transaction, orderId);

                // 2. Security Information
                populateSecurityInformation(transaction);

                // 3. Customer and Account Information
                populateCustomerAndAccountInformation(transaction, customerId, accountId);

                // 4. Order Execution Details
                populateOrderExecutionDetails(transaction);

                // 5. Risk and Compliance
                populateRiskAndCompliance(transaction);

                // 6. Market Data and Pricing
                populateMarketDataAndPricing(transaction);

                // 7. Settlement and Clearing
                populateSettlementAndClearing(transaction);

                // 8. Regulatory and Reporting
                populateRegulatoryAndReporting(transaction);

                // 9. Performance and Analytics
                populatePerformanceAndAnalytics(transaction);

                // 10. Common fields from base class
                populateLocationInformation(transaction);
                populateRiskAndFraudIndicators(transaction);

                return transaction;
        }

        private void populateCoreOrderDetails(Map<String, Object> transaction, String orderId) {
                LocalDateTime timestamp = generateTimestamp();
                String orderType = ORDER_TYPES[random.nextInt(ORDER_TYPES.length)];
                String orderSide = ORDER_SIDES[random.nextInt(ORDER_SIDES.length)];
                String orderStatus = ORDER_STATUSES[random.nextInt(ORDER_STATUSES.length)];
                String timeInForce = TIME_IN_FORCE[random.nextInt(TIME_IN_FORCE.length)];

                transaction.put("order_id", orderId);
                transaction.put("parent_order_id",
                                random.nextDouble() < 0.1
                                                ? "ORD" + UUID.randomUUID().toString().replace("-", "").substring(0, 12)
                                                : null);
                transaction.put("client_order_id",
                                "CLT" + UUID.randomUUID().toString().replace("-", "").substring(0, 10));
                transaction.put("order_type", orderType);
                transaction.put("order_side", orderSide);
                transaction.put("order_status", orderStatus);
                transaction.put("time_in_force", timeInForce);
                transaction.put("timestamp", timestamp.format(ISO_DATE_TIME) + "Z");
                transaction.put("order_date", timestamp.format(DATE_FORMATTER));
                transaction.put("order_time", timestamp.format(TIME_FORMATTER));
                transaction.put("order_timezone", "America/New_York");
                transaction.put("quantity", 1 + random.nextInt(10000));
                transaction.put("filled_quantity", orderStatus.equals("FILLED") ? transaction.get("quantity")
                                : orderStatus.equals("PARTIALLY_FILLED")
                                                ? random.nextInt((Integer) transaction.get("quantity"))
                                                : 0);
                transaction.put("remaining_quantity",
                                (Integer) transaction.get("quantity") - (Integer) transaction.get("filled_quantity"));
                transaction.put("disclosed_quantity", random.nextDouble() < 0.2 ? 100 + random.nextInt(500) : null);
                transaction.put("minimum_quantity", random.nextDouble() < 0.1 ? 50 + random.nextInt(200) : null);
        }

        private void populateSecurityInformation(Map<String, Object> transaction) {
                String securityType = SECURITY_TYPES[random.nextInt(SECURITY_TYPES.length)];
                String symbol;

                // Choose symbol based on security type
                if (securityType.equals("ETF")) {
                        symbol = ETF_SYMBOLS[random.nextInt(ETF_SYMBOLS.length)];
                } else {
                        symbol = STOCK_SYMBOLS[random.nextInt(STOCK_SYMBOLS.length)];
                }

                transaction.put("security_id", symbol);
                transaction.put("symbol", symbol);
                transaction.put("security_type", securityType);
                transaction.put("security_name", generateSecurityName(symbol, securityType));
                transaction.put("cusip", generateCusip());
                transaction.put("isin", "US" + generateCusip() + String.format("%02d", random.nextInt(100)));
                transaction.put("sedol", generateSedol());
                transaction.put("exchange", EXCHANGES[random.nextInt(EXCHANGES.length)]);
                transaction.put("primary_exchange", EXCHANGES[random.nextInt(EXCHANGES.length)]);
                transaction.put("currency", "USD");
                transaction.put("country_of_issue", "US");
                transaction.put("sector", generateSector(symbol));
                transaction.put("industry", generateIndustry(symbol));
                transaction.put("market_cap_category", generateMarketCapCategory());

                // Option-specific fields
                if (securityType.equals("OPTION")) {
                        LocalDateTime optionTimestamp = generateTimestamp();
                        transaction.put("underlying_symbol", STOCK_SYMBOLS[random.nextInt(STOCK_SYMBOLS.length)]);
                        transaction.put("option_type", random.nextBoolean() ? "CALL" : "PUT");
                        transaction.put("strike_price", roundToTwoDecimals(50 + random.nextDouble() * 200));
                        transaction.put("expiration_date",
                                        optionTimestamp.plusDays(1 + random.nextInt(365)).format(DATE_FORMATTER));
                        transaction.put("days_to_expiration", 1 + random.nextInt(365));
                }
        }

        private void populateCustomerAndAccountInformation(Map<String, Object> transaction, String customerId,
                        String accountId) {
                populateCustomerInformation(transaction, customerId);

                transaction.put("account_id", accountId);
                transaction.put("account_type", ACCOUNT_TYPES[random.nextInt(ACCOUNT_TYPES.length)]);
                transaction.put("account_name", "Account " + accountId.substring(4));
                transaction.put("account_status", random.nextDouble() < 0.95 ? "ACTIVE" : "RESTRICTED");
                transaction.put("account_balance", roundToTwoDecimals(1000 + random.nextDouble() * 999000));
                transaction.put("buying_power", roundToTwoDecimals(500 + random.nextDouble() * 499500));
                transaction.put("margin_balance", roundToTwoDecimals(random.nextDouble() * 50000));
                transaction.put("day_trading_buying_power", roundToTwoDecimals(random.nextDouble() * 100000));
                transaction.put("pattern_day_trader_flag", random.nextDouble() < 0.1);
                transaction.put("account_equity", roundToTwoDecimals(5000 + random.nextDouble() * 995000));
                transaction.put("net_liquidation_value", roundToTwoDecimals(5000 + random.nextDouble() * 995000));
        }

        private void populateOrderExecutionDetails(Map<String, Object> transaction) {
                double price = 10 + random.nextDouble() * 490; // $10-$500

                transaction.put("price", roundToTwoDecimals(price));
                transaction.put("stop_price",
                                transaction.get("order_type").toString().contains("STOP")
                                                ? roundToTwoDecimals(price * (0.95 + random.nextDouble() * 0.1))
                                                : null);
                transaction.put("limit_price",
                                transaction.get("order_type").toString().contains("LIMIT")
                                                ? roundToTwoDecimals(price * (0.98 + random.nextDouble() * 0.04))
                                                : null);
                transaction.put("average_fill_price",
                                (Integer) transaction.get("filled_quantity") > 0
                                                ? roundToTwoDecimals(price * (0.999 + random.nextDouble() * 0.002))
                                                : null);
                transaction.put("last_fill_price",
                                (Integer) transaction.get("filled_quantity") > 0
                                                ? roundToTwoDecimals(price * (0.999 + random.nextDouble() * 0.002))
                                                : null);
                transaction.put("last_fill_quantity",
                                (Integer) transaction.get("filled_quantity") > 0
                                                ? Math.min(100, (Integer) transaction.get("filled_quantity"))
                                                : null);
                transaction.put("total_fill_value",
                                (Integer) transaction.get("filled_quantity") > 0
                                                ? roundToTwoDecimals(
                                                                (Integer) transaction.get("filled_quantity") * price)
                                                : 0.0);

                transaction.put("execution_instructions",
                                EXECUTION_INSTRUCTIONS[random.nextInt(EXECUTION_INSTRUCTIONS.length)]);
                transaction.put("routing_destination",
                                ROUTING_DESTINATIONS[random.nextInt(ROUTING_DESTINATIONS.length)]);
                transaction.put("order_capacity", random.nextBoolean() ? "AGENCY" : "PRINCIPAL");
                transaction.put("liquidity_indicator", random.nextDouble() < 0.6 ? "ADDED" : "REMOVED");
                transaction.put("execution_venue", EXCHANGES[random.nextInt(EXCHANGES.length)]);
                transaction.put("contra_broker", "BRKR" + String.format("%03d", random.nextInt(1000)));
                transaction.put("execution_id",
                                "EXEC" + UUID.randomUUID().toString().replace("-", "").substring(0, 10));
                transaction.put("trade_id", "TRD" + UUID.randomUUID().toString().replace("-", "").substring(0, 10));
        }

        private void populateRiskAndCompliance(Map<String, Object> transaction) {
                transaction.put("pre_trade_risk_check", random.nextDouble() < 0.98 ? "PASSED" : "FAILED");
                transaction.put("post_trade_risk_check", random.nextDouble() < 0.99 ? "PASSED" : "FAILED");
                transaction.put("position_limit_check", random.nextDouble() < 0.95 ? "PASSED" : "WARNING");
                transaction.put("credit_limit_check", random.nextDouble() < 0.97 ? "PASSED" : "FAILED");
                transaction.put("regulatory_check", random.nextDouble() < 0.99 ? "PASSED" : "REVIEW_REQUIRED");
                transaction.put("wash_sale_flag", random.nextDouble() < 0.05);
                transaction.put("short_sale_exempt_flag", random.nextDouble() < 0.1);
                transaction.put("locate_required_flag", transaction.get("order_side").equals("SELL_SHORT"));
                transaction.put("locate_id",
                                transaction.get("locate_required_flag").equals(true)
                                                ? "LOC" + UUID.randomUUID().toString().replace("-", "").substring(0, 8)
                                                : null);
                transaction.put("best_execution_venue", EXCHANGES[random.nextInt(EXCHANGES.length)]);
                transaction.put("order_handling_instructions", random.nextDouble() < 0.2 ? "MANUAL" : "AUTOMATED");
        }

        private void populateMarketDataAndPricing(Map<String, Object> transaction) {
                double price = (Double) transaction.get("price");

                transaction.put("bid_price", roundToTwoDecimals(price * (0.998 + random.nextDouble() * 0.002)));
                transaction.put("ask_price", roundToTwoDecimals(price * (1.000 + random.nextDouble() * 0.002)));
                transaction.put("bid_size", 100 + random.nextInt(1000));
                transaction.put("ask_size", 100 + random.nextInt(1000));
                transaction.put("last_trade_price", roundToTwoDecimals(price * (0.999 + random.nextDouble() * 0.002)));
                transaction.put("last_trade_size", 100 + random.nextInt(500));
                transaction.put("volume", 1000 + random.nextInt(1000000));
                transaction.put("vwap", roundToTwoDecimals(price * (0.995 + random.nextDouble() * 0.01)));
                transaction.put("open_price", roundToTwoDecimals(price * (0.98 + random.nextDouble() * 0.04)));
                transaction.put("high_price", roundToTwoDecimals(price * (1.00 + random.nextDouble() * 0.05)));
                transaction.put("low_price", roundToTwoDecimals(price * (0.95 + random.nextDouble() * 0.05)));
                transaction.put("close_price", roundToTwoDecimals(price * (0.99 + random.nextDouble() * 0.02)));
                transaction.put("previous_close", roundToTwoDecimals(price * (0.98 + random.nextDouble() * 0.04)));
                transaction.put("price_change", roundToTwoDecimals(price - (Double) transaction.get("previous_close")));
                transaction.put("price_change_percent", roundToTwoDecimals(
                                ((Double) transaction.get("price_change") / (Double) transaction.get("previous_close"))
                                                * 100));
                transaction.put("volatility", roundToTwoDecimals(0.1 + random.nextDouble() * 0.5));
                transaction.put("beta", roundToTwoDecimals(0.5 + random.nextDouble() * 1.5));
        }

        private void populateSettlementAndClearing(Map<String, Object> transaction) {
                LocalDateTime timestamp = generateTimestamp();

                transaction.put("settlement_date", timestamp.plusDays(2).format(DATE_FORMATTER)); // T+2
                transaction.put("clearing_firm", "CLEAR" + String.format("%03d", random.nextInt(1000)));
                transaction.put("clearing_account", "CLR" + String.format("%08d", random.nextInt(100000000)));
                transaction.put("settlement_currency", "USD");
                transaction.put("settlement_amount", transaction.get("total_fill_value"));
                transaction.put("accrued_interest",
                                random.nextDouble() < 0.3 ? roundToTwoDecimals(random.nextDouble() * 100) : 0.0);
                transaction.put("commission", roundToTwoDecimals(0.5 + random.nextDouble() * 9.5));
                transaction.put("sec_fee", roundToTwoDecimals(random.nextDouble() * 0.1));
                transaction.put("taf_fee", roundToTwoDecimals(random.nextDouble() * 0.01));
                transaction.put("other_fees", roundToTwoDecimals(random.nextDouble() * 2.0));
                transaction.put("net_settlement_amount",
                                (Double) transaction.get("settlement_amount") -
                                                (Double) transaction.get("commission") -
                                                (Double) transaction.get("sec_fee") -
                                                (Double) transaction.get("taf_fee") -
                                                (Double) transaction.get("other_fees"));
        }

        private void populateRegulatoryAndReporting(Map<String, Object> transaction) {
                transaction.put("regulatory_transaction_id",
                                "REG" + UUID.randomUUID().toString().replace("-", "").substring(0, 12));
                transaction.put("cat_reporter_id", "CAT" + String.format("%06d", random.nextInt(1000000)));
                transaction.put("oats_reportable", random.nextDouble() < 0.8);
                transaction.put("large_trader_flag", random.nextDouble() < 0.05);
                transaction.put("institutional_account_flag", random.nextDouble() < 0.3);
                transaction.put("employee_account_flag", random.nextDouble() < 0.02);
                transaction.put("market_maker_flag", random.nextDouble() < 0.1);
                transaction.put("proprietary_trading_flag", random.nextDouble() < 0.15);
                transaction.put("algorithmic_trading_flag", random.nextDouble() < 0.4);
                transaction.put("high_frequency_trading_flag", random.nextDouble() < 0.1);
                transaction.put("dark_pool_flag", random.nextDouble() < 0.2);
                transaction.put("cross_trading_flag", random.nextDouble() < 0.1);
                transaction.put("internalization_flag", random.nextDouble() < 0.3);
        }

        private void populatePerformanceAndAnalytics(Map<String, Object> transaction) {
                transaction.put("order_latency_ms", 1 + random.nextInt(100));
                transaction.put("fill_rate", roundToTwoDecimals(random.nextDouble()));
                transaction.put("slippage", roundToTwoDecimals(-0.05 + random.nextDouble() * 0.1));
                transaction.put("implementation_shortfall", roundToTwoDecimals(-0.1 + random.nextDouble() * 0.2));
                transaction.put("market_impact", roundToTwoDecimals(random.nextDouble() * 0.05));
                transaction.put("timing_cost", roundToTwoDecimals(-0.02 + random.nextDouble() * 0.04));
                transaction.put("opportunity_cost", roundToTwoDecimals(random.nextDouble() * 0.03));
                transaction.put("arrival_price", (Double) transaction.get("price"));
                transaction.put("decision_price",
                                roundToTwoDecimals((Double) transaction.get("price")
                                                * (0.999 + random.nextDouble() * 0.002)));
                transaction.put("benchmark_price",
                                roundToTwoDecimals((Double) transaction.get("price")
                                                * (0.998 + random.nextDouble() * 0.004)));
                transaction.put("participation_rate", roundToTwoDecimals(0.01 + random.nextDouble() * 0.2));
                transaction.put("order_aggressiveness", roundToTwoDecimals(random.nextDouble()));
                transaction.put("market_conditions",
                                random.nextDouble() < 0.33 ? "VOLATILE"
                                                : random.nextDouble() < 0.5 ? "STABLE" : "TRENDING");

                // Historical metrics
                transaction.put("orders_count_7d", random.nextInt(50));
                transaction.put("orders_count_30d", random.nextInt(200));
                transaction.put("total_volume_7d", random.nextInt(100000));
                transaction.put("total_volume_30d", random.nextInt(500000));
                transaction.put("avg_order_size_7d", roundToTwoDecimals(100 + random.nextDouble() * 900));
                transaction.put("avg_order_size_30d", roundToTwoDecimals(100 + random.nextDouble() * 900));
                transaction.put("success_rate_7d", roundToTwoDecimals(0.7 + random.nextDouble() * 0.3));
                transaction.put("success_rate_30d", roundToTwoDecimals(0.7 + random.nextDouble() * 0.3));
        }

        // Helper methods
        private String generateSecurityName(String symbol, String securityType) {
                String[] companyNames = { "Corp", "Inc", "Ltd", "LLC", "Group", "Holdings", "Systems", "Technologies" };
                return symbol + " " + companyNames[random.nextInt(companyNames.length)];
        }

        private String generateCusip() {
                StringBuilder cusip = new StringBuilder();
                for (int i = 0; i < 9; i++) {
                        if (random.nextBoolean()) {
                                cusip.append((char) ('A' + random.nextInt(26)));
                        } else {
                                cusip.append(random.nextInt(10));
                        }
                }
                return cusip.toString();
        }

        private String generateSedol() {
                StringBuilder sedol = new StringBuilder();
                for (int i = 0; i < 7; i++) {
                        if (random.nextBoolean()) {
                                sedol.append((char) ('A' + random.nextInt(26)));
                        } else {
                                sedol.append(random.nextInt(10));
                        }
                }
                return sedol.toString();
        }

        private String generateSector(String symbol) {
                String[] sectors = { "Technology", "Healthcare", "Financial", "Consumer", "Industrial", "Energy",
                                "Utilities",
                                "Materials" };
                return sectors[random.nextInt(sectors.length)];
        }

        private String generateIndustry(String symbol) {
                String[] industries = { "Software", "Biotechnology", "Banking", "Retail", "Manufacturing", "Oil & Gas",
                                "Electric", "Mining" };
                return industries[random.nextInt(industries.length)];
        }

        private String generateMarketCapCategory() {
                String[] categories = { "LARGE_CAP", "MID_CAP", "SMALL_CAP", "MICRO_CAP" };
                return categories[random.nextInt(categories.length)];
        }
}
