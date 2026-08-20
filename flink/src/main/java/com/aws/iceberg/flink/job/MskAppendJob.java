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
import java.util.List;

/**
 * Flink job for MSK Source data (direct Kafka streaming).
 *
 * Consumes flat JSON records from MSK — no CDC envelope, no op field.
 * Appends all records to Iceberg (no upsert, no deletes).
 *
 * Dual-sink: Glue (primary) and S3 Tables (secondary). Both targets share the
 * same schema so one RowData satisfies both.
 */
public class MskAppendJob {

    private static final Logger LOG = LoggerFactory.getLogger(MskAppendJob.class);

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
                config.isS3TablesEnabled() ? config.s3TablesFinancialTableId() : null);

        buildPipeline(env, config, glueLoader, s3TablesLoader,
                config.getBrokerageTopic(),
                config.brokerageTableId(),
                config.isS3TablesEnabled() ? config.s3TablesBrokerageTableId() : null);

        env.execute("MskAppendJob");
    }

    private static void buildPipeline(
            StreamExecutionEnvironment env,
            FlinkJobConfig config,
            CatalogLoader glueLoader,
            CatalogLoader s3TablesLoader,
            String topic,
            String glueTableId,
            String s3TablesTableId) throws IOException {

        KafkaSource<String> source = KafkaSourceUtil.createSource(config, topic);

        TableIdentifier glueId = TableIdentifier.parse(glueTableId);
        Schema icebergSchema = loadSchema(glueLoader, glueId);

        DataStream<RowData> stream = env
                .fromSource(source, WatermarkStrategy.noWatermarks(), "kafka-" + topic)
                .map(new FlatJsonMapper(icebergSchema))
                .name("parse-" + topic);

        // Primary sink — Glue catalog (append-only)
        FlinkSink.forRowData(stream)
                .tableLoader(TableLoader.fromCatalog(glueLoader, glueId))
                .append();
        LOG.info("Glue pipeline: {} -> {} (append)", topic, glueTableId);

        // Secondary sink — S3 Tables (append-only, only when enabled)
        if (s3TablesLoader != null && s3TablesTableId != null) {
            TableIdentifier s3Id = TableIdentifier.parse(s3TablesTableId);
            FlinkSink.forRowData(stream)
                    .tableLoader(TableLoader.fromCatalog(s3TablesLoader, s3Id))
                    .append();
            LOG.info("S3 Tables pipeline: {} -> {} (append)", topic, s3TablesTableId);
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

    /** Maps flat JSON to RowData using Iceberg schema for type conversion. Always INSERT. */
    static class FlatJsonMapper implements MapFunction<String, RowData> {
        private static final ObjectMapper MAPPER = new ObjectMapper();
        private final Schema schema;

        FlatJsonMapper(Schema schema) {
            this.schema = schema;
        }

        @Override
        public RowData map(String value) throws Exception {
            JsonNode node = MAPPER.readTree(value);
            List<Types.NestedField> columns = schema.columns();
            GenericRowData row = new GenericRowData(columns.size());
            for (int i = 0; i < columns.size(); i++) {
                Types.NestedField col = columns.get(i);
                row.setField(i, JsonToRowDataConverter.convert(node.get(col.name()), col.type()));
            }
            row.setRowKind(RowKind.INSERT);
            return row;
        }
    }
}
