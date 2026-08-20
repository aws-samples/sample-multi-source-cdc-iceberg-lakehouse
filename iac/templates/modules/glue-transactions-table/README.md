# Glue Transactions Table Module

This Terraform module creates AWS Glue Catalog tables for transaction data in Apache Iceberg format, supporting both financial and brokerage transaction schemas with comprehensive field definitions for analytics and data lake operations.

## Features

- **Dual Transaction Types**: Supports both financial (101 fields) and brokerage (180+ fields) transaction schemas
- **Apache Iceberg Format**: Creates external tables with Iceberg metadata operation support
- **Comprehensive Schema**: Complete field definitions matching synthetic data generation schemas
- **Primary Key Configuration**: Automatic primary key assignment based on transaction type
- **S3 Integration**: Configurable S3 bucket location for Iceberg table storage
- **Parquet Format**: Optimized for analytics with columnar storage format

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Glue Catalog      │    │  Apache Iceberg     │    │   S3 Data Lake      │
│                     │    │     Table           │    │                     │
│ • Financial Schema  │───►│                     │───►│ • Parquet Files     │
│ • Brokerage Schema  │    │ • Primary Keys      │    │ • Partitioned Data  │
│ • 101/180+ Fields   │    │ • Schema Evolution  │    │ • Compressed        │
│ • External Tables   │    │ • ACID Transactions │    │                     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Usage

### Financial Transactions Table

```hcl
module "financial_transactions_table" {
  source = "../../templates/modules/glue-transactions-table"

  APP             = "${APP_NAME}"
  ENV             = "prod"
  DATABASE_NAME   = "iceberg_lakehouse"
  S3_BUCKET_NAME  = "my-data-lake-bucket"
  TABLE_NAME      = "financial_transactions"
  TABLE_TYPE      = "financial"
}
```

### Brokerage Transactions Table

```hcl
module "brokerage_transactions_table" {
  source = "../../templates/modules/glue-transactions-table"

  APP             = "${APP_NAME}"
  ENV             = "prod"
  DATABASE_NAME   = "iceberg_lakehouse"
  S3_BUCKET_NAME  = "my-data-lake-bucket"
  TABLE_NAME      = "brokerage_transactions"
  TABLE_TYPE      = "brokerage"
}
```

### Multiple Tables Example

```hcl
# Financial transactions from multiple sources
module "oracle_financial_table" {
  source = "../../templates/modules/glue-transactions-table"

  APP             = var.APP
  ENV             = var.ENV
  DATABASE_NAME   = "iceberg_lakehouse"
  S3_BUCKET_NAME  = var.S3_BUCKET_NAME
  TABLE_NAME      = "oracle_financial_transactions"
  TABLE_TYPE      = "financial"
}

module "aurora_brokerage_table" {
  source = "../../templates/modules/glue-transactions-table"

  APP             = var.APP
  ENV             = var.ENV
  DATABASE_NAME   = "iceberg_lakehouse"
  S3_BUCKET_NAME  = var.S3_BUCKET_NAME
  TABLE_NAME      = "aurora_brokerage_transactions"
  TABLE_TYPE      = "brokerage"
}
```

## Inputs

| Name           | Description                                    | Type     | Default | Required |
| -------------- | ---------------------------------------------- | -------- | ------- | :------: |
| APP            | Application name for resource naming           | `string` | n/a     |   yes    |
| ENV            | Environment name                               | `string` | n/a     |   yes    |
| DATABASE_NAME  | Glue database name for the table               | `string` | n/a     |   yes    |
| S3_BUCKET_NAME | S3 bucket name for Iceberg table storage      | `string` | n/a     |   yes    |
| TABLE_NAME     | Name of the transactions table                 | `string` | n/a     |   yes    |
| TABLE_TYPE     | Type of table to create                        | `string` | n/a     |   yes    |

### TABLE_TYPE Values

- **`financial`**: Creates table with 101 fields for financial transaction data
- **`brokerage`**: Creates table with 180+ fields for brokerage/trading data

## Outputs

| Name       | Description                    |
| ---------- | ------------------------------ |
| table_name | Name of the created Glue table |
| table_arn  | ARN of the created Glue table  |

## Schema Definitions

### Financial Transactions Schema (101 Fields)

**Core Transaction Fields:**
- `transaction_id` (Primary Key), `transaction_reference_id`, `transaction_type`
- `timestamp`, `transaction_date`, `transaction_amount`, `currency`
- `transaction_status`, `transaction_description`, `transaction_category`

**Customer Information:**
- `customer_id`, `customer_uuid`, `customer_age`, `customer_gender`
- `customer_income`, `customer_residence_country/state/city`
- `customer_kyc_status`, `customer_risk_category`, `customer_vip_flag`

**Merchant Details:**
- `merchant_id`, `merchant_name`, `merchant_category_code`
- `merchant_rating`, `merchant_country/state/city`
- `merchant_chargeback_rate`, `merchant_high_risk_flag`

**Payment Information:**
- `payment_method`, `payment_card_last_four`, `payment_card_issuer`
- `payment_card_country`, `payment_card_funding_type`

**Fraud & Risk Analytics:**
- `is_fraud`, `fraud_score`, `velocity_score`, `behavioral_risk_score`
- `geo_anomaly_flag`, `high_risk_ip_flag`, `chargeback_history_flag`

**Transaction History:**
- `transaction_count_7d/30d/90d/365d`, `transaction_amount_7d/30d/90d/365d`
- `avg_transaction_amount_7d/30d`, `online_transaction_ratio_30d`

### Brokerage Transactions Schema (180+ Fields)

**Core Order Details:**
- `order_id` (Primary Key), `parent_order_id`, `client_order_id`
- `order_type`, `order_side`, `order_status`, `time_in_force`
- `quantity`, `filled_quantity`, `remaining_quantity`

**Security Information:**
- `security_id`, `symbol`, `security_type`, `security_name`
- `cusip`, `isin`, `sedol`, `exchange`, `currency`
- `sector`, `industry`, `market_cap_category`
- `option_type`, `strike_price`, `expiration_date`

**Account & Customer:**
- `account_id`, `account_type`, `account_balance`, `account_equity`
- `buying_power`, `margin_balance`, `pattern_day_trader_flag`
- Complete customer demographics (same as financial schema)

**Execution Details:**
- `price`, `stop_price`, `limit_price`, `average_fill_price`
- `execution_instructions`, `routing_destination`, `liquidity_indicator`
- `execution_venue`, `contra_broker`, `trade_id`

**Risk & Compliance:**
- `pre_trade_risk_check`, `post_trade_risk_check`
- `wash_sale_flag`, `short_sale_exempt_flag`
- `regulatory_check`, `position_limit_check`

## Table Configuration

### Iceberg Properties

- **Format**: Parquet for optimal analytics performance
- **Table Type**: External table with S3 storage location
- **Metadata Operation**: CREATE for initial Iceberg table setup
- **Primary Keys**: Automatically configured based on table type

### Storage Location

Tables are stored in S3 with the following structure:
```
s3://{S3_BUCKET_NAME}/{TABLE_NAME}/
├── metadata/
├── data/
└── snapshots/
```

## Integration Points

### Data Sources
- **DMS Replication**: Target for Oracle and Aurora CDC data
- **Firehose Streams**: Destination for real-time streaming data
- **Lambda Processing**: Schema validation and transformation

### Query Engines
- **Amazon Athena**: Direct querying of Iceberg tables
- **SageMaker**: Machine learning model training and inference

## Implementation Details

### Schema Evolution Support

Apache Iceberg format supports:
- Adding new columns without breaking existing queries
- Column type evolution (widening types)
- Partition evolution for performance optimization
- Time travel queries for historical analysis

### Performance Optimization

- **Columnar Storage**: Parquet format for efficient analytics
- **Compression**: Built-in compression for storage efficiency
- **Partitioning**: Configurable partitioning strategies
- **Indexing**: Iceberg metadata for fast query planning

## Dependencies

This module requires:

- **Terraform**: >= 1.8.0
- **AWS Provider**: >= 5.0
- **Glue Database**: Must exist before creating tables
- **S3 Bucket**: Must exist with appropriate permissions
- **IAM Permissions**:
  - Glue catalog read/write access
  - S3 bucket read/write access
  - KMS permissions for encrypted buckets

## Related Modules

- `../../foundation/glue-databases`: Creates required Glue databases
- `../../foundation/buckets`: Provides S3 storage for Iceberg tables
- `../msk-firehose-ingestion`: Streams data to these tables
- `../lambda`: Processes and validates data before storage
