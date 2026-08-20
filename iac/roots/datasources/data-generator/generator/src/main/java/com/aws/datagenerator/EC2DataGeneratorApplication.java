// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.datagenerator;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Main application for generating transaction data on EC2
 * Supports multiple destinations (console, MSK, database) and various
 * generation modes
 * Now supports both financial and brokerage transaction types
 */
public class EC2DataGeneratorApplication {
    private static final Logger logger = LoggerFactory.getLogger(EC2DataGeneratorApplication.class);
    private static final ObjectMapper objectMapper = new ObjectMapper();

    // Configuration parameters with defaults
    private static int numRecordsToGenerate = 5;
    private static boolean prettyPrintJson = true;
    private static int intervalMs = 1000;
    private static int durationSeconds = 60;
    private static boolean continuousMode = false;
    private static String region = "us-east-1";
    private static int numThreads = 1;

    // Transaction type configuration
    private static String transactionType = "financial"; // financial or brokerage or both

    // MSK configuration
    private static boolean enableMsk = false;
    private static String mskBootstrapServersSecret = null;
    private static String mskTopic = null;

    // Database configuration
    private static boolean enableDatabase = false;
    private static String dbSecretName = null;
    private static String dbTableName = null; // Will be set based on transaction type
    private static boolean createTable = true;

    // List of active generator threads
    private static final List<GenericDataGeneratorThread> generatorThreads = new ArrayList<>();

    // Rate tracking
    private static final AtomicInteger totalMessagesGenerated = new AtomicInteger(0);
    private static volatile boolean rateLoggingActive = false;

    public static void main(String[] args) {
        logger.info("Starting Transaction Data Generator");

        // Parse command line arguments
        parseArgs(args);

        // Create data writers and generators based on configuration
        List<DataWriterGeneratorPair> pairs = createDataWriterGeneratorPairs();

        if (pairs.isEmpty()) {
            logger.info("No data writers configured. Running in console output mode.");
            runConsoleOutputMode();
        } else {
            // Start generator threads for each writer-generator pair
            for (DataWriterGeneratorPair pair : pairs) {
                GenericDataGeneratorThread thread;

                if (continuousMode) {
                    thread = new GenericDataGeneratorThread(pair.writer, pair.generator, durationSeconds, intervalMs,
                            true);
                } else {
                    thread = new GenericDataGeneratorThread(pair.writer, pair.generator, numRecordsToGenerate,
                            intervalMs);
                }

                generatorThreads.add(thread);
                thread.start();
            }

            // Start rate logging thread
            startRateLogging();

            // Add shutdown hook to stop threads gracefully
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                logger.info("Shutting down generator threads...");
                rateLoggingActive = false;
                for (GenericDataGeneratorThread thread : generatorThreads) {
                    thread.stopGeneration();
                }
            }));

            // Wait for all threads to complete
            for (GenericDataGeneratorThread thread : generatorThreads) {
                try {
                    thread.join();
                } catch (InterruptedException e) {
                    logger.warn("Interrupted while waiting for thread to complete", e);
                    Thread.currentThread().interrupt();
                }
            }

            // Stop rate logging
            rateLoggingActive = false;
        }

        logger.info("Data generation complete.");
    }

    /**
     * Start rate logging thread
     */
    private static void startRateLogging() {
        rateLoggingActive = true;
        Thread rateLoggingThread = new Thread(() -> {
            int previousCount = 0;
            long previousTime = System.currentTimeMillis();

            while (rateLoggingActive) {
                try {
                    Thread.sleep(10000);

                    int currentCount = totalMessagesGenerated.get();
                    long currentTime = System.currentTimeMillis();

                    int messagesInInterval = currentCount - previousCount;
                    long timeInterval = currentTime - previousTime;
                    double rate = (messagesInInterval * 1000.0) / timeInterval; // messages per second

                    long activeThreads = generatorThreads.stream().filter(Thread::isAlive).count();

                    logger.info("Message generation rate: {} msg/sec | Total messages: {} | Active threads: {}",
                            String.format("%.2f", rate), currentCount, activeThreads);

                    previousCount = currentCount;
                    previousTime = currentTime;
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        });

        rateLoggingThread.setDaemon(true);
        rateLoggingThread.setName("RateLogger");
        rateLoggingThread.start();
    }

    /**
     * Increment message counter (called by generator threads)
     */
    public static void incrementMessageCount() {
        totalMessagesGenerated.incrementAndGet();
    }

    /**
     * Helper class to pair data writers with generators
     */
    private static class DataWriterGeneratorPair {
        final DataWriter writer;
        final BaseTransactionGenerator generator;

        DataWriterGeneratorPair(DataWriter writer, BaseTransactionGenerator generator) {
            this.writer = writer;
            this.generator = generator;
        }
    }

    /**
     * Parse command line arguments
     * 
     * @param args Command line arguments
     */
    private static void parseArgs(String[] args) {
        for (int i = 0; i < args.length; i++) {
            if (args[i].equals("--num-records") && i + 1 < args.length) {
                numRecordsToGenerate = Integer.parseInt(args[++i]);
            } else if (args[i].equals("--pretty-print")) {
                prettyPrintJson = true;
            } else if (args[i].equals("--no-pretty-print")) {
                prettyPrintJson = false;
            } else if (args[i].equals("--interval") && i + 1 < args.length) {
                intervalMs = Integer.parseInt(args[++i]);
            } else if (args[i].equals("--duration") && i + 1 < args.length) {
                durationSeconds = Integer.parseInt(args[++i]);
            } else if (args[i].equals("--continuous")) {
                continuousMode = true;
            } else if (args[i].equals("--region") && i + 1 < args.length) {
                region = args[++i];
            } else if (args[i].equals("--threads") && i + 1 < args.length) {
                numThreads = Integer.parseInt(args[++i]);
                if (numThreads < 1) {
                    System.err.println("Error: --threads must be at least 1");
                    System.exit(1);
                }
            }
            // Transaction type options
            else if (args[i].equals("--transaction-type") && i + 1 < args.length) {
                transactionType = args[++i].toLowerCase();
                if (!transactionType.equals("financial") && !transactionType.equals("brokerage")
                        && !transactionType.equals("both")) {
                    System.err.println("Error: --transaction-type must be 'financial', 'brokerage', or 'both'");
                    System.exit(1);
                }
            }
            // MSK options
            else if (args[i].equals("--enable-msk")) {
                enableMsk = true;
            } else if (args[i].equals("--bootstrap-servers-secret") && i + 1 < args.length) {
                mskBootstrapServersSecret = args[++i];
            } else if (args[i].equals("--topic") && i + 1 < args.length) {
                mskTopic = args[++i];
            }
            // Database options
            else if (args[i].equals("--enable-database")) {
                enableDatabase = true;
            } else if (args[i].equals("--db-secret") && i + 1 < args.length) {
                dbSecretName = args[++i];
            } else if (args[i].equals("--table-name") && i + 1 < args.length) {
                dbTableName = args[++i];
            } else if (args[i].equals("--no-create-table")) {
                createTable = false;
            } else if (args[i].equals("--help")) {
                printUsage();
                System.exit(0);
            }
        }

        // Set default table names based on transaction type if not specified
        if (dbTableName == null) {
            if (transactionType.equals("financial")) {
                dbTableName = "financial_transactions";
            } else if (transactionType.equals("brokerage")) {
                dbTableName = "brokerage_transactions";
            } else {
                dbTableName = "financial_transactions"; // Default for 'both' mode
            }
        }

        // Validate required parameters
        boolean hasErrors = false;

        if (enableMsk) {
            if (mskBootstrapServersSecret == null || mskBootstrapServersSecret.trim().isEmpty()) {
                System.err.println("Error: --bootstrap-servers-secret is required when using --enable-msk");
                hasErrors = true;
            }

            if (mskTopic == null || mskTopic.trim().isEmpty()) {
                System.err.println("Error: --topic is required when using --enable-msk");
                hasErrors = true;
            }
        }

        if (enableDatabase) {
            if (dbSecretName == null || dbSecretName.trim().isEmpty()) {
                System.err.println("Error: --db-secret is required when using --enable-database");
                hasErrors = true;
            }
        }

        if (hasErrors) {
            System.err.println("\nUse --help for usage information");
            System.exit(1);
        }

        // Log configuration
        logger.info("Configuration:");
        logger.info("  Transaction Type: {}", transactionType);
        if (!enableMsk && !enableDatabase) {
            logger.info("  Mode: Console Output");
            logger.info("  Number of Records to Generate: {}", numRecordsToGenerate);
            logger.info("  Pretty Print JSON: {}", prettyPrintJson);
        } else {
            if (continuousMode) {
                logger.info("  Mode: Continuous");
                logger.info("  Duration (seconds): {}", durationSeconds);
            } else {
                logger.info("  Mode: Fixed Records");
                logger.info("  Number of Records: {}", numRecordsToGenerate);
            }
            logger.info("  Interval (ms): {}", intervalMs);
            logger.info("  Threads per destination: {}", numThreads);
            logger.info("  Region: {}", region);

            if (enableMsk) {
                logger.info("  MSK Enabled: true");
                logger.info("  Bootstrap Servers Secret: {}", mskBootstrapServersSecret);
                logger.info("  Topic: {}", mskTopic);
            }

            if (enableDatabase) {
                logger.info("  Database Enabled: true");
                logger.info("  Database Secret: {}", dbSecretName);
                logger.info("  Table Name: {}", dbTableName);
                logger.info("  Create Table: {}", createTable);
            }
        }
    }

    /**
     * Print usage information
     */
    private static void printUsage() {
        System.out.println("Transaction Data Generator");
        System.out.println("Usage: java -jar datagenerator.jar [options]");
        System.out.println("\nGeneral Options:");
        System.out.println("  --num-records <n>             Number of records to generate (default: 5)");
        System.out.println("  --interval <n>                Interval between messages in ms (default: 1000)");
        System.out.println("  --continuous                  Run continuously");
        System.out
                .println("  --duration <n>                Duration in seconds to run in continuous mode (default: 60)");
        System.out.println("  --region <s>                  AWS region (default: us-east-1)");
        System.out.println("  --threads <n>                 Number of threads per destination (default: 1)");
        System.out.println(
                "  --transaction-type <s>        Transaction type: 'financial', 'brokerage', or 'both' (default: financial)");
        System.out.println("  --help                        Print this help message");

        System.out.println("\nConsole Output Options:");
        System.out.println("  --pretty-print                Pretty print JSON output (default: true)");
        System.out.println("  --no-pretty-print             Disable pretty printing of JSON output");

        System.out.println("\nMSK Publishing Options:");
        System.out.println("  --enable-msk                  Enable publishing to MSK");
        System.out.println("  --bootstrap-servers-secret <s> Secret name containing MSK bootstrap servers");
        System.out.println("  --topic <s>                   MSK topic");

        System.out.println("\nDatabase Options:");
        System.out.println("  --enable-database             Enable writing to database");
        System.out.println("  --db-secret <s>               Secret name containing database connection details");
        System.out.println(
                "  --table-name <s>              Table name to write to (auto-determined by transaction type if not specified)");
        System.out.println("  --no-create-table             Don't create the table if it doesn't exist");

        System.out.println("\nTransaction Type Examples:");
        System.out.println("  --transaction-type financial  Generate financial transaction data");
        System.out.println("  --transaction-type brokerage  Generate brokerage transaction data");
        System.out.println("  --transaction-type both       Generate both types (creates separate threads)");
    }

    /**
     * Create data writer and generator pairs based on configuration
     * 
     * @return List of data writer and generator pairs
     */
    private static List<DataWriterGeneratorPair> createDataWriterGeneratorPairs() {
        List<DataWriterGeneratorPair> pairs = new ArrayList<>();

        // Determine which transaction types to generate
        List<String> typesToGenerate = new ArrayList<>();
        if (transactionType.equals("both")) {
            typesToGenerate.add("financial");
            typesToGenerate.add("brokerage");
        } else {
            typesToGenerate.add(transactionType);
        }

        // Create pairs for each transaction type
        for (String type : typesToGenerate) {
            String tableNameForType;

            if (type.equals("financial")) {
                tableNameForType = transactionType.equals("both") ? "financial_transactions" : dbTableName;
            } else {
                tableNameForType = transactionType.equals("both") ? "brokerage_transactions" : dbTableName;
            }

            // Create MSK writer if enabled
            if (enableMsk) {
                try {
                    for (int threadNum = 1; threadNum <= numThreads; threadNum++) {
                        BaseTransactionGenerator generator = type.equals("financial")
                                ? new FinancialTransactionGenerator()
                                : new BrokerageTransactionGenerator();
                        MSKTransactionProducer mskProducer = new MSKTransactionProducer(
                                "MSK-Producer-" + type + "-" + threadNum, mskBootstrapServersSecret, mskTopic, region);
                        pairs.add(new DataWriterGeneratorPair(mskProducer, generator));
                    }
                    logger.info("Created {} MSK producer threads for {} transactions on topic: {}", numThreads, type,
                            mskTopic);
                } catch (Exception e) {
                    logger.error("Failed to create MSK producer for {} transactions", type, e);
                }
            }

            // Create database writer if enabled
            if (enableDatabase) {
                try {
                    for (int threadNum = 1; threadNum <= numThreads; threadNum++) {
                        BaseTransactionGenerator generator = type.equals("financial")
                                ? new FinancialTransactionGenerator()
                                : new BrokerageTransactionGenerator();
                        DatabaseTransactionWriter dbWriter = new DatabaseTransactionWriter(
                                "Database-Writer-" + type + "-" + threadNum, dbSecretName, region, tableNameForType,
                                type, createTable);
                        pairs.add(new DataWriterGeneratorPair(dbWriter, generator));
                    }
                    logger.info("Created {} database writer threads for {} transactions on table: {}", numThreads, type,
                            tableNameForType);
                } catch (Exception e) {
                    logger.error("Failed to create database writer for {} transactions", type, e);
                }
            }
        }

        return pairs;
    }

    /**
     * Run in console output mode
     */
    private static void runConsoleOutputMode() {
        System.out.println("Generating " + numRecordsToGenerate + " transaction records of type: " + transactionType);

        // Determine which generators to use
        List<BaseTransactionGenerator> generators = new ArrayList<>();
        if (transactionType.equals("both")) {
            generators.add(new FinancialTransactionGenerator());
            generators.add(new BrokerageTransactionGenerator());
        } else if (transactionType.equals("financial")) {
            generators.add(new FinancialTransactionGenerator());
        } else {
            generators.add(new BrokerageTransactionGenerator());
        }

        int recordsPerGenerator = transactionType.equals("both") ? numRecordsToGenerate / 2 : numRecordsToGenerate;

        for (BaseTransactionGenerator generator : generators) {
            String generatorType = generator instanceof FinancialTransactionGenerator ? "Financial" : "Brokerage";
            System.out.println("\n=== " + generatorType + " Transactions ===");

            for (int i = 0; i < recordsPerGenerator; i++) {
                try {
                    // Generate a transaction
                    Map<String, Object> transaction = generator.generateTransaction();

                    // Convert to JSON
                    String json;
                    if (prettyPrintJson) {
                        json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(transaction);
                    } else {
                        json = objectMapper.writeValueAsString(transaction);
                    }

                    // Print to console
                    System.out.println("\n" + generatorType + " Transaction #" + (i + 1) + ":");
                    System.out.println(json);

                } catch (Exception e) {
                    logger.error("Error generating {} transaction", generatorType, e);
                }
            }
        }
    }
}