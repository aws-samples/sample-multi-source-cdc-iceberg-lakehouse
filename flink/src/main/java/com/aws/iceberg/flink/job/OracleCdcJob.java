// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.iceberg.flink.job;

import com.aws.iceberg.flink.util.FlinkJobConfig;
import com.aws.iceberg.flink.util.IcebergCatalogUtil;
import com.aws.iceberg.flink.util.JsonToRowDataConverter;
import com.aws.iceberg.flink.util.KafkaSourceUtil;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.data.GenericRowData;
import org.apache.flink.table.data.RowData;
import org.apache.flink.types.RowKind;
import org.apache.iceberg.Schema;
import org.apache.iceberg.catalog.TableIdentifier;
import org.apache.iceberg.flink.CatalogLoader;
import org.apache.iceberg.flink.TableLoader;
import org.apache.iceberg.flink.sink.FlinkSink;
import org.apache.iceberg.types.Types;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.Collections;
import java.util.List;

/**
 * Flink job for Oracle CDC data.
 *
 * Consumes Debezium-flattened JSON records from MSK Ingest (post-ExtractNewRecordState).
 * Oracle LogMiner sends UPPERCASE column names (Oracle's native casing), so this job
 * does case-insensitive field lookups to match the lowercase Iceberg table schema.
 *
 * Maps __op to RowKind: c/r → INSERT, u → UPDATE_AFTER, d → DELETE.
 * Writes to Iceberg with equality deletes via upsert mode.
 *
 * Dual-sink: Glue (primary) and S3 Tables (secondary). Both targets share the
 * same schema so one RowData satisfies both.
 */
public class OracleCdcJob {

    private static final Logger LOG = LoggerFactory.getLogger(OracleCdcJob.class);

    public static void main(String[] args) throws Exception {
        FlinkJobConfig config = args.length > 0
                ? FlinkJobConfig.fromArgs(args)
                : FlinkJobConfig.load();

        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.enableCheckpointing(config.getCheckpointIntervalMs());

        CatalogLoader glueLoader = IcebergCatalogUtil.glueCatalogLoader(config);
        CatalogLoader s3TablesLoader = IcebergCatalogUtil.s3TablesCatalogLoader(config);

        buildPipeline(env, config, glueLoader, s3TablesLoader,
                config.getFinancialTopic(),
                config.financialTableId(),
                config.isS3TablesEnabled() ? config.s3TablesFinancialTableId() : null,
                "transaction_id");

        buildPipeline(env, config, glueLoader, s3TablesLoader,
                config.getBrokerageTopic(),
                config.brokerageTableId(),
                config.isS3TablesEnabled() ? config.s3TablesBrokerageTableId() : null,
                "order_id");

        env.execute("OracleCdcJob");
    }

    private static void buildPipeline(
            StreamExecutionEnvironment env,
            FlinkJobConfig config,
            CatalogLoader glueLoader,
            CatalogLoader s3TablesLoader,
            String topic,
            String glueTableId,
            String s3TablesTableId,
            String primaryKey) throws IOException {

        KafkaSource<String> source = KafkaSourceUtil.createSource(config, topic);

        TableIdentifier glueId = TableIdentifier.parse(glueTableId);
        Schema icebergSchema = loadSchema(glueLoader, glueId);

        DataStream<RowData> stream = env
                .fromSource(source, WatermarkStrategy.noWatermarks(), "kafka-" + topic)
                .map(new OracleFlatMapper(icebergSchema))
                .name("parse-" + topic);

        // Primary sink — Glue catalog
        FlinkSink.forRowData(stream)
                .tableLoader(TableLoader.fromCatalog(glueLoader, glueId))
                .upsert(true)
                .equalityFieldColumns(Collections.singletonList(primaryKey))
                .append();
        LOG.info("Glue pipeline: {} -> {} (pk={})", topic, glueTableId, primaryKey);

        // Secondary sink — S3 Tables (only when enabled)
        if (s3TablesLoader != null && s3TablesTableId != null) {
            TableIdentifier s3Id = TableIdentifier.parse(s3TablesTableId);
            FlinkSink.forRowData(stream)
                    .tableLoader(TableLoader.fromCatalog(s3TablesLoader, s3Id))
                    .upsert(true)
                    .equalityFieldColumns(Collections.singletonList(primaryKey))
                    .append();
            LOG.info("S3 Tables pipeline: {} -> {} (pk={})", topic, s3TablesTableId, primaryKey);
        }
    }

    private static Schema loadSchema(CatalogLoader loader, TableIdentifier id) {
        TableLoader tl = TableLoader.fromCatalog(loader, id);
        tl.open();
        try {
            return tl.loadTable().schema();
        } finally {
            try { tl.close(); } catch (IOException ignored) {}
        }
    }

    /**
     * Maps Oracle Debezium-flattened JSON (UPPERCASE fields) to RowData.
     * Looks up each Iceberg column name case-insensitively to match Oracle's uppercase keys.
     */
    static class OracleFlatMapper implements MapFunction<String, RowData> {
        private static final ObjectMapper MAPPER = new ObjectMapper();
        private static final Logger MAPPER_LOG = LoggerFactory.getLogger(OracleFlatMapper.class);
        private final Schema schema;
        private transient long sampleCounter = 0;

        OracleFlatMapper(Schema schema) {
            this.schema = schema;
        }

        @Override
        public RowData map(String value) throws Exception {
            if (sampleCounter++ % 100 == 0) {
                MAPPER_LOG.info("Sample Kafka record: {}",
                        value.length() > 2000 ? value.substring(0, 2000) + "..." : value);
            }
            JsonNode node = MAPPER.readTree(value);

            String op = "c";
            if (node.has("__op")) op = node.get("__op").asText();
            else if (node.has("__OP")) op = node.get("__OP").asText();
            RowKind rowKind = switch (op) {
                case "u" -> RowKind.UPDATE_AFTER;
                case "d" -> RowKind.DELETE;
                default -> RowKind.INSERT;
            };

            List<Types.NestedField> columns = schema.columns();
            GenericRowData row = new GenericRowData(columns.size());
            for (int i = 0; i < columns.size(); i++) {
                Types.NestedField col = columns.get(i);
                row.setField(i,
                        JsonToRowDataConverter.convert(getCaseInsensitive(node, col.name()), col.type()));
            }
            row.setRowKind(rowKind);
            return row;
        }

        /** Look up a JSON field by name, case-insensitive (Oracle sends UPPERCASE). */
        private static JsonNode getCaseInsensitive(JsonNode node, String name) {
            JsonNode direct = node.get(name);
            if (direct != null) return direct;
            JsonNode upper = node.get(name.toUpperCase());
            if (upper != null) return upper;
            return node.get(name.toLowerCase());
        }
    }
}
