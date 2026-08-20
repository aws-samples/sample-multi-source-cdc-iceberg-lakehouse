// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.iceberg.flink.util;

import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.KafkaSourceOptions;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.kafka.clients.consumer.ConsumerConfig;

import java.util.Properties;
import java.util.regex.Pattern;

/**
 * Builds Flink KafkaSource instances configured for MSK IAM authentication.
 */
public final class KafkaSourceUtil {

    /** How often the enumerator re-lists topics to discover late-created ones. */
    private static final String PARTITION_DISCOVERY_INTERVAL_MS = "30000";

    private KafkaSourceUtil() {}

    /** KafkaSource for JSON-encoded topics (all sources now use JSON). */
    public static KafkaSource<String> createSource(FlinkJobConfig config, String topic) {
        return KafkaSource.<String>builder()
                .setBootstrapServers(config.getBootstrapServers())
                // Subscribe by exact-match pattern rather than a static topic list.
                // A static list makes the enumerator call AdminClient.describeTopics(),
                // which throws UnknownTopicOrPartition (fatal, global job failure) when a
                // topic does not exist yet. Debezium creates a per-table topic lazily —
                // only on the first captured change — so the brokerage topic is often
                // absent when the job starts, crash-looping the whole job (both the fin
                // and brk pipelines) until it appears. A pattern subscriber instead calls
                // listTopics() + regex filter: an absent topic simply yields zero
                // partitions (no crash), and periodic partition discovery re-lists and
                // picks the topic up once Debezium creates it. Pattern.quote + anchors
                // make this match exactly the one intended topic.
                .setTopicPattern(Pattern.compile("^" + Pattern.quote(topic) + "$"))
                .setGroupId(config.getConsumerGroupId())
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setValueOnlyDeserializer(new SimpleStringSchema())
                .setProperties(mskIamProperties())
                .setProperty(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest")
                // Ensure discovery is enabled so a topic created after job start is found.
                .setProperty(KafkaSourceOptions.PARTITION_DISCOVERY_INTERVAL_MS.key(),
                        PARTITION_DISCOVERY_INTERVAL_MS)
                .build();
    }

    /** MSK IAM SASL/SSL properties for the Kafka consumer. */
    private static Properties mskIamProperties() {
        Properties props = new Properties();
        props.setProperty("security.protocol", "SASL_SSL");
        props.setProperty("sasl.mechanism", "AWS_MSK_IAM");
        props.setProperty("sasl.jaas.config",
                "software.amazon.msk.auth.iam.IAMLoginModule required;");
        props.setProperty("sasl.client.callback.handler.class",
                "software.amazon.msk.auth.iam.IAMClientCallbackHandler");
        return props;
    }
}
