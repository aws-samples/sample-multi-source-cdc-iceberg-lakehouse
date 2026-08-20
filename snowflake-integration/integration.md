# Snowflake Integration

This document provides comprehensive documentation on how to create a Catalog Integration from Snowflake to AWS Glue REST Iceberg API.

## Overview

The Glue Iceberg Data Catalog can be integrated with Snowflake to enable querying of Iceberg tables directly from Snowflake. This integration allows user to leverage Snowflake's powerful analytics capabilities while keeping thier data in the S3-based Iceberg format.

### Prerequisites

- Snowflake account with appropriate permissions
- AWS IAM role for Snowflake integration
- Deployed Glue Data Catalog from this template

### Setting Up Snowflake Integration

#### Step 1: Create IAM Role for Snowflake

Create an IAM role that Snowflake can assume to access your Glue Data Catalog using the values recorded above:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "GLUE_AWS_IAM_USER_ARN"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "GLUE_AWS_EXTERNAL_ID"
        }
      }
    }
  ]
}
```

**Replace the placeholders:**
- `GLUE_AWS_IAM_USER_ARN`: Use the IAM user ARN from the table above
- `GLUE_AWS_EXTERNAL_ID`: Use the external ID from the table above

Attach the following policy to the role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "glue:GetDatabase",
        "glue:GetDatabases",
        "glue:GetTable",
        "glue:GetTables",
        "glue:GetPartition",
        "glue:GetPartitions",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:glue:*:*:catalog",
        "arn:aws:glue:*:*:database/*",
        "arn:aws:glue:*:*:table/*/*",
        "arn:aws:s3:::your-iceberg-bucket",
        "arn:aws:s3:::your-iceberg-bucket/*"
      ]
    }
  ]
}
```

#### Step 2: Create Catalog Integration in Snowflake

Use the following SQL command in Snowflake to create the catalog integration (for example, with `${APP_NAME}_${ENV_NAME}_aurora_financial_transactions_database`):

```sql
CREATE CATALOG INTEGRATION glue_rest_catalog_int
  CATALOG_SOURCE = ICEBERG_REST
  TABLE_FORMAT = ICEBERG
  CATALOG_NAMESPACE = '${APP_NAME}_${ENV_NAME}_aurora_financial_transactions_database'
  REST_CONFIG = (
    CATALOG_URI = 'https://glue.us-east-1.amazonaws.com/iceberg'
    CATALOG_API_TYPE = AWS_GLUE
    ACCESS_DELEGATION_MODE = VENDED_CREDENTIALS
  )
  REST_AUTHENTICATION = (
    TYPE = SIGV4
    SIGV4_IAM_ROLE = 'arn:aws:iam::YOUR-ACCOUNT:role/SnowflakeGlueRole'
    SIGV4_SIGNING_REGION = 'us-east-1'
  )
  REFRESH_INTERVAL_SECONDS = 120
  ENABLED = TRUE;
```

#### Step 3: Retrieve the AWS IAM user and external ID for your Snowflake account

Once the integration is set up:

```sql
-- Retrieve the AWS IAM user and external ID for your Snowflake account
DESCRIBE CATALOG INTEGRATION glue_rest_catalog_int;
```

Before setting up the integration, you'll need to record the following values from your Snowflake account:

| Value | Description |
|-------|-------------|
| `GLUE_AWS_IAM_USER_ARN` | The AWS IAM user created for your Snowflake account, for example, `arn:aws:iam::123456789012:user/abc1-b-self1234`. Snowflake provisions a single IAM user for your entire Snowflake account. All Glue catalog integrations in your account use that IAM user. |
| `GLUE_AWS_EXTERNAL_ID` | An external ID for establishing a trust relationship. |

Update the trust policy for the same IAM role that you specified with the ARN when you created the catalog integration (`GLUE_AWS_ROLE_ARN`). Add the values that you recorded in the previous step to the trust policy (details are [here](https://docs.snowflake.com/en/user-guide/tables-iceberg-configure-catalog-integration-rest-glue#step-4-grant-the-iam-user-access-to-the-aws-glue-data-catalog)).

```sql
-- Verify the connection
SELECT SYSTEM$VERIFY_CATALOG_INTEGRATION('glue_rest_catalog_int');
```

#### Step 4: Create Snowflake Table Integration

Use the following SQL command in Snowflake to create local iceberg table (for example, with `aurora_financial_transactions_table`):

```sql
create iceberg table aurora_financial_transactions_table
  CATALOG='glue_rest_catalog_int'
  CATALOG_TABLE_NAME="aurora_financial_transactions_table" 
  AUTO_REFRESH = TRUE;
```

```sql
-- Query financial transactions from Aurora database
SELECT 
  order_id,
  symbol,
  order_type,
  quantity,
  price,
  timestamp
FROM aurora_financial_transactions_table
WHERE order_date >= '2024-01-01'
LIMIT 100;
```

### Troubleshooting

Common issues and solutions:

1. **Permission Errors**: Ensure the IAM role has proper permissions for both Glue and S3
2. **Region Mismatch**: Verify that the Glue region matches your S3 bucket region
3. **Catalog Namespace**: Use the correct AWS account ID as the catalog namespace
4. **External ID**: Ensure the external ID in the trust policy matches Snowflake's requirements

For detailed configuration options and advanced features, refer to the [Snowflake documentation](https://docs.snowflake.com/en/sql-reference/sql/create-catalog-integration-rest).
