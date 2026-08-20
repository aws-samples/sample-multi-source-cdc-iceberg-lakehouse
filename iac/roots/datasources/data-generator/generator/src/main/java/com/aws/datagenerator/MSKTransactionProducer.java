// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.datagenerator;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.serialization.StringSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueResponse;

import java.util.Map;
import java.util.Properties;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Produces transaction data to MSK
 */
public class MSKTransactionProducer implements DataWriter {
    private static final Logger logger = LoggerFactory.getLogger(MSKTransactionProducer.class);
    private static final ObjectMapper objectMapper = new ObjectMapper();

    private final String bootstrapServers;
    private final String topic;
    private final Region region;
    private final KafkaProducer<String, String> producer;
    private final AtomicInteger recordsWritten = new AtomicInteger(0);
    private final String name;

    /**
     * Constructor that retrieves bootstrap servers from Secrets Manager
     * 
     * @param name                   Descriptive name for this writer (e.g., "MSK
     *                               Producer")
     * @param bootstrapServersSecret Name of the secret containing bootstrap servers
     * @param topic                  Kafka topic
     * @param regionName             AWS region name
     */
    public MSKTransactionProducer(String name, String bootstrapServersSecret, String topic, String regionName) {
        this.name = name;
        this.region = regionName != null ? Region.of(regionName) : Region.US_EAST_1;

        // Always get bootstrap servers from Secrets Manager
        this.bootstrapServers = getSecret(bootstrapServersSecret);
        logger.info("[{}] Retrieved bootstrap servers from Secrets Manager", name);

        this.topic = topic;
        this.producer = createKafkaProducer();

        logger.info("[{}] Initialized MSKTransactionProducer with topic: {}, region: {}",
                name, topic, region);
    }

    /**
     * Create a Kafka producer
     * 
     * @return A configured KafkaProducer
     */
    private KafkaProducer<String, String> createKafkaProducer() {
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.RETRIES_CONFIG, 3);
        props.put(ProducerConfig.RETRY_BACKOFF_MS_CONFIG, 1000);
        props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "gzip");

        // Add MSK IAM authentication
        props.put("security.protocol", "SASL_SSL");
        props.put("sasl.mechanism", "AWS_MSK_IAM");
        props.put("sasl.jaas.config", "software.amazon.msk.auth.iam.IAMLoginModule required;");
        props.put("sasl.client.callback.handler.class", "software.amazon.msk.auth.iam.IAMClientCallbackHandler");

        return new KafkaProducer<>(props);
    }

    /**
     * Get a secret from AWS Secrets Manager
     * 
     * @param secretName The name of the secret
     * @return The secret value
     */
    private String getSecret(String secretName) {
        try (SecretsManagerClient client = SecretsManagerClient.builder()
                .region(region)
                .build()) {

            GetSecretValueRequest request = GetSecretValueRequest.builder()
                    .secretId(secretName)
                    .build();

            GetSecretValueResponse response = client.getSecretValue(request);
            return response.secretString();
        }
    }

    /**
     * Write a single transaction to MSK
     * 
     * @param transaction The transaction data to write
     * @return true if the write was successful, false otherwise
     */
    @Override
    public boolean writeTransaction(Map<String, Object> transaction) {
        try {
            String transactionId = (String) transaction.get("transaction_id");

            // Convert to JSON
            String jsonData = objectMapper.writeValueAsString(transaction);

            // Create and send record
            ProducerRecord<String, String> record = new ProducerRecord<>(topic, transactionId, jsonData);
            RecordMetadata metadata = producer.send(record).get();

            logger.debug("[{}] Sent transaction: topic={}, partition={}, offset={}, key={}",
                    name, metadata.topic(), metadata.partition(), metadata.offset(), transactionId);

            recordsWritten.incrementAndGet();
            return true;
        } catch (Exception e) {
            logger.error("[{}] Error publishing transaction", name, e);
            return false;
        }
    }

    /**
     * Get the number of records written to MSK
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
     * Close the producer
     */
    @Override
    public void close() {
        if (producer != null) {
            producer.flush();
            producer.close();
            logger.info("[{}] MSK producer closed", name);
        }
    }
}
