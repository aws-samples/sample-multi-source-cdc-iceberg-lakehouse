// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.iceberg.flink.util;

import com.amazonaws.services.kinesisanalytics.runtime.KinesisAnalyticsRuntime;

import java.io.IOException;
import java.util.Map;
import java.util.Properties;

/**
 * Loads runtime configuration from AWS Managed Flink application properties.
 *
 * Property groups expected in the Managed Flink application:
 *   KafkaSource  — bootstrap.servers, topic.financial, topic.brokerage, group.id
 *   IcebergSink  — warehouse, database, table.financial, table.brokerage
 *                  (optional) s3tables.warehouse, s3tables.database — enables dual-sink
 *   FlinkApp     — checkpoint.interval.ms (optional, default 60000)
 */
public final class FlinkJobConfig {

    private static final String GROUP_KAFKA = "KafkaSource";
    private static final String GROUP_ICEBERG = "IcebergSink";
    private static final String GROUP_APP = "FlinkApp";
    private static final long DEFAULT_CHECKPOINT_INTERVAL_MS = 60_000L;

    private final String bootstrapServers;
    private final String financialTopic;
    private final String brokerageTopic;
    private final String consumerGroupId;
    private final String warehouse;
    private final String database;
    private final String financialTable;
    private final String brokerageTable;
    private final String s3TablesWarehouse;
    private final String s3TablesDatabase;
    private final String region;
    private final long checkpointIntervalMs;

    private FlinkJobConfig(Map<String, Properties> appProperties) {
        Properties kafka = appProperties.getOrDefault(GROUP_KAFKA, new Properties());
        Properties iceberg = appProperties.getOrDefault(GROUP_ICEBERG, new Properties());
        Properties app = appProperties.getOrDefault(GROUP_APP, new Properties());

        this.bootstrapServers = require(kafka, "bootstrap.servers");
        this.financialTopic = require(kafka, "topic.financial");
        this.brokerageTopic = require(kafka, "topic.brokerage");
        this.consumerGroupId = require(kafka, "group.id");
        this.warehouse = require(iceberg, "warehouse");
        this.database = require(iceberg, "database");
        this.financialTable = require(iceberg, "table.financial");
        this.brokerageTable = require(iceberg, "table.brokerage");
        // Optional — omitted when S3 Tables dual-sink is not desired
        this.s3TablesWarehouse = iceberg.getProperty("s3tables.warehouse");
        this.s3TablesDatabase = iceberg.getProperty("s3tables.database");
        this.region = app.getProperty("region", System.getenv().getOrDefault("AWS_REGION", "us-east-1"));
        this.checkpointIntervalMs = Long.parseLong(
                app.getProperty("checkpoint.interval.ms",
                        String.valueOf(DEFAULT_CHECKPOINT_INTERVAL_MS)));
    }

    /** Load config from Managed Flink runtime properties. */
    public static FlinkJobConfig load() throws IOException {
        return new FlinkJobConfig(KinesisAnalyticsRuntime.getApplicationProperties());
    }

    /** Load config from CLI args (for local testing). Args format: --key value. */
    public static FlinkJobConfig fromArgs(String[] args) {
        Map<String, String> params = new java.util.HashMap<>();
        for (int i = 0; i < args.length - 1; i += 2) {
            if (args[i].startsWith("--")) {
                params.put(args[i].substring(2), args[i + 1]);
            }
        }
        Properties kafka = new Properties();
        kafka.setProperty("bootstrap.servers", required(params, "bootstrap.servers"));
        kafka.setProperty("topic.financial", required(params, "topic.financial"));
        kafka.setProperty("topic.brokerage", required(params, "topic.brokerage"));
        kafka.setProperty("group.id", required(params, "group.id"));

        Properties iceberg = new Properties();
        iceberg.setProperty("warehouse", required(params, "warehouse"));
        iceberg.setProperty("database", required(params, "database"));
        iceberg.setProperty("table.financial", required(params, "table.financial"));
        iceberg.setProperty("table.brokerage", required(params, "table.brokerage"));
        if (params.containsKey("s3tables.warehouse")) {
            iceberg.setProperty("s3tables.warehouse", params.get("s3tables.warehouse"));
        }
        if (params.containsKey("s3tables.database")) {
            iceberg.setProperty("s3tables.database", params.get("s3tables.database"));
        }

        Properties app = new Properties();
        if (params.containsKey("checkpoint.interval.ms")) {
            app.setProperty("checkpoint.interval.ms", params.get("checkpoint.interval.ms"));
        }
        if (params.containsKey("region")) {
            app.setProperty("region", params.get("region"));
        }

        return new FlinkJobConfig(Map.of(GROUP_KAFKA, kafka, GROUP_ICEBERG, iceberg, GROUP_APP, app));
    }

    private static String required(Map<String, String> params, String key) {
        String value = params.get(key);
        if (value == null) {
            throw new IllegalArgumentException("Missing required CLI arg: --" + key);
        }
        return value;
    }

    public String getBootstrapServers() { return bootstrapServers; }
    public String getFinancialTopic() { return financialTopic; }
    public String getBrokerageTopic() { return brokerageTopic; }
    public String getConsumerGroupId() { return consumerGroupId; }
    public String getWarehouse() { return warehouse; }
    public String getDatabase() { return database; }
    public String getFinancialTable() { return financialTable; }
    public String getBrokerageTable() { return brokerageTable; }
    public String getS3TablesWarehouse() { return s3TablesWarehouse; }
    public String getS3TablesDatabase() { return s3TablesDatabase; }
    public String getRegion() { return region; }
    public long getCheckpointIntervalMs() { return checkpointIntervalMs; }

    /** True when both S3 Tables warehouse and database are configured. */
    public boolean isS3TablesEnabled() {
        return s3TablesWarehouse != null && !s3TablesWarehouse.isBlank()
                && s3TablesDatabase != null && !s3TablesDatabase.isBlank();
    }

    /** Full Iceberg table identifier: database.table */
    public String financialTableId() { return database + "." + financialTable; }
    public String brokerageTableId() { return database + "." + brokerageTable; }

    /** S3 Tables identifiers — only valid when {@link #isS3TablesEnabled()}. */
    public String s3TablesFinancialTableId() { return s3TablesDatabase + "." + financialTable; }
    public String s3TablesBrokerageTableId() { return s3TablesDatabase + "." + brokerageTable; }

    private static String require(Properties props, String key) {
        String value = props.getProperty(key);
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Missing required config: " + key);
        }
        return value;
    }
}
