// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.datagenerator;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Thread for generating and writing financial transaction data to a destination
 */
public class DataGeneratorThread extends Thread {
    private static final Logger logger = LoggerFactory.getLogger(DataGeneratorThread.class);

    private final DataWriter writer;
    private final FinancialTransactionGenerator generator;
    private final int numRecords;
    private final boolean continuousMode;
    private final int intervalMs;
    private final long durationMs;
    private final AtomicBoolean running = new AtomicBoolean(true);

    /**
     * Constructor for fixed number of records mode
     * 
     * @param writer     The data writer to use
     * @param numRecords Number of records to generate
     * @param intervalMs Interval between records in milliseconds
     */
    public DataGeneratorThread(DataWriter writer, int numRecords, int intervalMs) {
        this.writer = writer;
        this.generator = new FinancialTransactionGenerator();
        this.numRecords = numRecords;
        this.continuousMode = false;
        this.intervalMs = intervalMs;
        this.durationMs = 0;
        setName("DataGenerator-" + writer.getName());
    }

    /**
     * Constructor for continuous mode
     * 
     * @param writer          The data writer to use
     * @param durationSeconds Duration in seconds to run
     * @param intervalMs      Interval between records in milliseconds
     */
    public DataGeneratorThread(DataWriter writer, int durationSeconds, int intervalMs, boolean continuousMode) {
        this.writer = writer;
        this.generator = new FinancialTransactionGenerator();
        this.numRecords = 0;
        this.continuousMode = continuousMode;
        this.intervalMs = intervalMs;
        this.durationMs = durationSeconds * 1000L;
        setName("DataGenerator-" + writer.getName());
    }

    /**
     * Stop the thread
     */
    public void stopGeneration() {
        running.set(false);
        interrupt();
    }

    /**
     * Run the thread
     */
    @Override
    public void run() {
        logger.info("[{}] Starting data generation thread", writer.getName());

        try {
            if (continuousMode) {
                runContinuousMode();
            } else {
                runFixedRecordsMode();
            }
        } catch (InterruptedException e) {
            logger.info("[{}] Data generation thread interrupted", writer.getName());
            Thread.currentThread().interrupt();
        } catch (Exception e) {
            logger.error("[{}] Error in data generation thread", writer.getName(), e);
        } finally {
            try {
                writer.close();
            } catch (Exception e) {
                logger.error("[{}] Error closing writer", writer.getName(), e);
            }
        }

        logger.info("[{}] Data generation thread completed. Records written: {}",
                writer.getName(), writer.getRecordsWritten());
    }

    /**
     * Run in fixed number of records mode
     */
    private void runFixedRecordsMode() throws InterruptedException {
        logger.info("[{}] Generating {} records with interval of {} ms",
                writer.getName(), numRecords, intervalMs);

        for (int i = 0; i < numRecords && running.get(); i++) {
            Map<String, Object> transaction = generator.generateTransaction();
            boolean success = writer.writeTransaction(transaction);

            if (success) {
                if (writer.getRecordsWritten() % 100 == 0) {
                    logger.info("[{}] Generated {} records", writer.getName(), writer.getRecordsWritten());
                }
            } else {
                logger.warn("[{}] Failed to write transaction: {}", writer.getName(),
                        transaction.get("transaction_id"));
            }

            if (intervalMs > 0) {
                Thread.sleep(intervalMs);
            }
        }
    }

    /**
     * Run in continuous mode
     */
    private void runContinuousMode() throws InterruptedException {
        if (durationMs > 0) {
            logger.info("[{}] Generating records continuously for {} seconds with interval of {} ms",
                    writer.getName(), durationMs / 1000, intervalMs);
        } else {
            logger.info("[{}] Generating records continuously with interval of {} ms until stopped",
                    writer.getName(), intervalMs);
        }

        long startTime = System.currentTimeMillis();
        long endTime = durationMs > 0 ? startTime + durationMs : Long.MAX_VALUE;

        while (running.get() && System.currentTimeMillis() < endTime) {
            Map<String, Object> transaction = generator.generateTransaction();
            boolean success = writer.writeTransaction(transaction);

            if (success) {
                if (writer.getRecordsWritten() % 100 == 0) {
                    logger.info("[{}] Generated {} records", writer.getName(), writer.getRecordsWritten());
                }
            } else {
                logger.warn("[{}] Failed to write transaction: {}", writer.getName(),
                        transaction.get("transaction_id"));
            }

            if (intervalMs > 0) {
                Thread.sleep(intervalMs);
            }
        }
    }
}
