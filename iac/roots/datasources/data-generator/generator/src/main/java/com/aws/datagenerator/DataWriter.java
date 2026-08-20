// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.datagenerator;

import java.util.Map;

/**
 * Interface for writing financial transaction data to various destinations
 */
public interface DataWriter extends AutoCloseable {

    /**
     * Write a single transaction to the destination
     * 
     * @param transaction The transaction data to write
     * @return true if the write was successful, false otherwise
     */
    boolean writeTransaction(Map<String, Object> transaction);

    /**
     * Get the number of records written to the destination
     * 
     * @return Number of records written
     */
    int getRecordsWritten();

    /**
     * Get the name of this data writer for logging purposes
     * 
     * @return Name of the data writer
     */
    String getName();
}
