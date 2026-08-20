// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package com.aws.iceberg.flink.util;

import org.apache.flink.table.api.TableEnvironment;
import org.apache.hadoop.conf.Configuration;
import org.apache.iceberg.CatalogProperties;
import org.apache.iceberg.aws.glue.GlueCatalog;
import org.apache.iceberg.aws.s3.S3FileIO;
import org.apache.iceberg.flink.CatalogLoader;
import org.apache.iceberg.rest.RESTCatalog;

import java.util.HashMap;
import java.util.Map;

/**
 * Creates Iceberg CatalogLoaders for Flink jobs. Two catalogs are supported:
 *   - Glue Data Catalog (primary — reads table schemas, writes Iceberg via S3FileIO)
 *   - S3 Tables (secondary — AWS managed Iceberg via the REST catalog API)
 *
 * Both catalogs are wired concurrently per job so every record lands in both places.
 */
public final class IcebergCatalogUtil {

    public static final String GLUE_CATALOG_NAME = "glue_catalog";
    public static final String S3_TABLES_CATALOG_NAME = "s3_tables_catalog";
    public static final String S3_TABLES_ENDPOINT_FORMAT = "https://s3tables.%s.amazonaws.com/iceberg";
    public static final String S3_TABLES_SIGNING_NAME = "s3tables";

    private IcebergCatalogUtil() {}

    /** Register the Glue catalog in a Flink TableEnvironment (for SQL jobs). */
    public static void registerCatalog(TableEnvironment tableEnv, FlinkJobConfig config) {
        String ddl = String.format(
                "CREATE CATALOG %s WITH ("
                        + "'type'='iceberg',"
                        + "'catalog-impl'='org.apache.iceberg.aws.glue.GlueCatalog',"
                        + "'io-impl'='org.apache.iceberg.aws.s3.S3FileIO',"
                        + "'warehouse'='%s'"
                        + ")",
                GLUE_CATALOG_NAME, config.getWarehouse());
        tableEnv.executeSql(ddl);
        tableEnv.useCatalog(GLUE_CATALOG_NAME);
    }

    /** Build a Glue CatalogLoader (primary sink — also used for schema discovery). */
    public static CatalogLoader glueCatalogLoader(FlinkJobConfig config) {
        Map<String, String> props = new HashMap<>();
        props.put(CatalogProperties.CATALOG_IMPL, GlueCatalog.class.getName());
        props.put(CatalogProperties.WAREHOUSE_LOCATION, config.getWarehouse());
        props.put(CatalogProperties.FILE_IO_IMPL, S3FileIO.class.getName());
        return CatalogLoader.custom(GLUE_CATALOG_NAME, props, new Configuration(), GlueCatalog.class.getName());
    }

    /**
     * Build an S3 Tables CatalogLoader (secondary sink) using Iceberg's REST catalog
     * with SigV4 auth against the S3 Tables endpoint.
     * Returns null if S3 Tables is not configured for this job.
     */
    public static CatalogLoader s3TablesCatalogLoader(FlinkJobConfig config) {
        if (!config.isS3TablesEnabled()) {
            return null;
        }
        Map<String, String> props = new HashMap<>();
        props.put(CatalogProperties.CATALOG_IMPL, RESTCatalog.class.getName());
        props.put(CatalogProperties.URI, String.format(S3_TABLES_ENDPOINT_FORMAT, config.getRegion()));
        props.put(CatalogProperties.WAREHOUSE_LOCATION, config.getS3TablesWarehouse());
        props.put(CatalogProperties.FILE_IO_IMPL, S3FileIO.class.getName());
        props.put("rest.sigv4-enabled", "true");
        props.put("rest.signing-name", S3_TABLES_SIGNING_NAME);
        props.put("rest.signing-region", config.getRegion());
        return CatalogLoader.custom(S3_TABLES_CATALOG_NAME, props, new Configuration(), RESTCatalog.class.getName());
    }

    // ------------------------------------------------------------------------
    // Backwards-compatible alias for existing callers that pre-dated dual-sink.
    // ------------------------------------------------------------------------

    /** @deprecated use {@link #glueCatalogLoader(FlinkJobConfig)} instead. */
    @Deprecated
    public static CatalogLoader catalogLoader(FlinkJobConfig config) {
        return glueCatalogLoader(config);
    }
}
