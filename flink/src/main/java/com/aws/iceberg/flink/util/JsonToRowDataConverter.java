// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.iceberg.flink.util;

import com.fasterxml.jackson.databind.JsonNode;
import org.apache.flink.table.data.DecimalData;
import org.apache.flink.table.data.StringData;
import org.apache.flink.table.data.TimestampData;
import org.apache.iceberg.types.Type;
import org.apache.iceberg.types.Types;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;

/**
 * Converts JSON field values to the Flink RowData Java types that Iceberg
 * writers expect, based on each column's Iceberg type.
 */
public final class JsonToRowDataConverter {

    private JsonToRowDataConverter() {}

    /** Convert a JSON node to the Java type matching the given Iceberg column. */
    public static Object convert(JsonNode node, Type icebergType) {
        if (node == null || node.isNull()) {
            return null;
        }
        Type.TypeID id = icebergType.typeId();
        switch (id) {
            case BOOLEAN:   return node.asBoolean();
            case INTEGER:   return node.asInt();
            case LONG:      return node.asLong();
            case FLOAT:     return (float) node.asDouble();
            case DOUBLE:    return node.asDouble();
            case DATE:
                try {
                    return node.isNumber()
                            ? node.asInt()
                            : (int) LocalDate.parse(node.asText()).toEpochDay();
                } catch (Exception e) { return null; }
            case TIMESTAMP:
                try {
                    return toTimestampData(node, ((Types.TimestampType) icebergType).shouldAdjustToUTC());
                } catch (Exception e) { return null; }
            case DECIMAL: {
                Types.DecimalType dt = (Types.DecimalType) icebergType;
                try {
                    BigDecimal bd;
                    if (node.isNumber()) {
                        bd = node.decimalValue();
                    } else {
                        String text = node.asText();
                        // Debezium encodes Postgres NUMERIC as base64 of two's-complement bytes
                        // at the table's declared scale. Try numeric parse first, fall back to base64.
                        try {
                            bd = new BigDecimal(text);
                        } catch (NumberFormatException nfe) {
                            byte[] bytes = java.util.Base64.getDecoder().decode(text);
                            bd = new BigDecimal(new java.math.BigInteger(bytes), dt.scale());
                        }
                    }
                    return DecimalData.fromBigDecimal(bd, dt.precision(), dt.scale());
                } catch (Exception e) {
                    return null;
                }
            }
            case STRING:
            case UUID:
            default:
                return StringData.fromString(node.asText());
        }
    }

    private static TimestampData toTimestampData(JsonNode node, boolean adjustToUtc) {
        // Debezium often emits timestamps as epoch micros/millis (long)
        if (node.isNumber()) {
            long val = node.asLong();
            // Heuristic: > 1e14 = microseconds, else milliseconds
            long millis = val > 1_000_000_000_000_000L ? val / 1000 : val;
            return TimestampData.fromInstant(Instant.ofEpochMilli(millis));
        }
        String text = node.asText();
        try {
            if (adjustToUtc) {
                return TimestampData.fromInstant(OffsetDateTime.parse(text).toInstant());
            }
            return TimestampData.fromLocalDateTime(LocalDateTime.parse(text));
        } catch (Exception e) {
            return TimestampData.fromInstant(Instant.parse(text));
        }
    }
}
