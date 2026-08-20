# Flink Iceberg Sink

Apache Flink application that consumes CDC events from Amazon MSK and writes them to Apache Iceberg tables on S3 (via the Glue Data Catalog) and S3 Tables.

## Architecture

This application implements **Path 2** of the Iceberg Data Lakehouse. A single fat JAR contains four Flink jobs, selected at runtime via an application property:

| Job Class | Source | Description |
|-----------|--------|-------------|
| `OracleCdcJob` | Debezium Oracle (MSK) | Parses Debezium envelopes, extracts `after` payload, writes to Iceberg |
| `AuroraCdcJob` | Debezium PostgreSQL (MSK) | Parses Debezium envelopes with `pgoutput`, writes to Iceberg |
| `CockroachCdcJob` | CockroachDB changefeed (MSK) | Parses CockroachDB CDC JSON envelopes, writes to Iceberg |
| `MskAppendJob` | Direct MSK topic | Append-only ingestion (no CDC unwrapping), writes to Iceberg |

Each job writes to both a Glue-cataloged Iceberg table (S3 data lake) and an S3 Tables managed table.

## Prerequisites

- Java 17+
- Apache Maven 3.8+

## Build

```bash
mvn clean package -DskipTests
```

This produces a fat JAR at `target/flink-iceberg-sink-1.0-SNAPSHOT.jar` with all runtime dependencies shaded in (Iceberg, Kafka connector, MSK IAM auth, Jackson, Hadoop).

## Configuration

When deployed to AWS Managed Apache Flink, configuration is provided via **application properties** (key-value groups). The `MainDispatcher` reads the `main.class` property to determine which job to run.

### Required Property Groups

| Group | Key | Description |
|-------|-----|-------------|
| `FlinkApplicationProperties` | `main.class` | Fully qualified job class (e.g., `com.aws.iceberg.flink.job.OracleCdcJob`) |
| `FlinkApplicationProperties` | `aws.region` | AWS region for Glue/S3 (e.g., `us-east-1`) |
| `FlinkApplicationProperties` | `kafka.bootstrap.servers` | MSK bootstrap servers (IAM auth) |
| `FlinkApplicationProperties` | `kafka.topic.pattern` | Regex pattern for source topics |
| `FlinkApplicationProperties` | `iceberg.catalog.name` | Glue catalog name |
| `FlinkApplicationProperties` | `iceberg.database` | Target Iceberg database |
| `FlinkApplicationProperties` | `iceberg.table` | Target Iceberg table |
| `FlinkApplicationProperties` | `s3tables.catalog.warehouse` | S3 Tables bucket ARN |
| `FlinkApplicationProperties` | `s3tables.namespace` | S3 Tables namespace |
| `FlinkApplicationProperties` | `s3tables.table` | S3 Tables table name |

## Deployment

The fat JAR is uploaded to S3 and referenced by the Managed Apache Flink application Terraform module at `iac/roots/flink/`.

```bash
# Upload to the artifacts bucket
aws s3 cp target/flink-iceberg-sink-1.0-SNAPSHOT.jar \
  s3://${APP_NAME}-${ENV_NAME}-iceberg-datalake-primary/flink-apps/

# Deploy via Terraform
make deploy-flink
```

## Project Structure

```
flink/
├── pom.xml                              # Maven build with shade plugin
└── src/main/java/com/aws/iceberg/flink/
    ├── MainDispatcher.java              # Entry point — dispatches to job class
    ├── job/
    │   ├── OracleCdcJob.java            # Oracle Debezium CDC → Iceberg
    │   ├── AuroraCdcJob.java            # Aurora Debezium CDC → Iceberg
    │   ├── CockroachCdcJob.java         # CockroachDB changefeed → Iceberg
    │   └── MskAppendJob.java            # Direct MSK append → Iceberg
    └── util/
        ├── FlinkJobConfig.java          # Configuration reader
        ├── KafkaSourceUtil.java         # Kafka source builder with IAM auth
        ├── IcebergCatalogUtil.java      # Glue + S3 Tables catalog setup
        └── JsonToRowDataConverter.java  # JSON → Flink RowData conversion
```

## License

This project is licensed under the MIT-0 License. See the [LICENSE](../LICENSE) file.
