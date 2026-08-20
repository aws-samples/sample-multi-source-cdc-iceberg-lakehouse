# Firehose Lambda Transformer Module

This Terraform module creates a Lambda function for transforming DMS envelope data in Kinesis Data Firehose streams, flattening CDC records for Iceberg table ingestion.

## Features

- **DMS Data Flattening**: Transforms DMS CDC envelope format to flat transaction records
- **Automatic Deployment**: Creates Lambda function with embedded Python code
- **Firehose Integration**: Designed specifically for Kinesis Data Firehose processing
- **Error Handling**: Processes records with proper error handling and logging
- **Reusable Design**: Uses the standardized Lambda module for consistent deployment

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Firehose Stream   │    │  Lambda Transformer │    │   Iceberg Table     │
│                     │    │                     │    │                     │
│ • DMS Envelope      │───►│ • Flatten Records   │───►│ • Flat Schema       │
│ • CDC Format        │    │ • Extract Data      │    │ • Query Ready       │
│ • Nested Structure  │    │ • Transform Fields  │    │ • Analytics Ready   │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Usage

```hcl
module "firehose_lambda_transformer" {
  source = "../../../templates/modules/firehose-lambda-transformer"

  APP    = "${APP_NAME}"
  ENV    = "dev"
  SOURCE = "oracle"
}
```

## Transformation Logic

The Lambda function processes DMS CDC records by:

1. **Envelope Extraction**: Extracts the `data` field from DMS envelope
2. **Field Flattening**: Converts nested structures to flat fields
3. **Type Conversion**: Handles data type transformations
4. **Record Validation**: Ensures required fields are present
5. **Error Handling**: Returns processing status for each record

### Input Format (DMS Envelope)
```json
{
  "data": {
    "transaction_id": "12345",
    "amount": 100.50,
    "timestamp": "2025-01-01T10:00:00Z"
  },
  "metadata": {
    "timestamp": "2025-01-01T10:00:01Z",
    "record-type": "data",
    "operation": "insert"
  }
}
```

### Output Format (Flattened)
```json
{
  "transaction_id": "12345",
  "amount": 100.50,
  "timestamp": "2025-01-01T10:00:00Z"
}
```

## Requirements

| Name      | Version |
| --------- | ------- |
| terraform | >= 1.8  |
| aws       | >= 5.0  |

## Providers

| Name | Version |
| ---- | ------- |
| aws  | >= 5.0  |

## Inputs

| Name   | Description                                           | Type     | Default | Required |
| ------ | ----------------------------------------------------- | -------- | ------- | :------: |
| APP    | Application name used for resource naming and tagging | `string` | n/a     |   yes    |
| ENV    | Environment name used for resource naming and tagging | `string` | n/a     |   yes    |
| SOURCE | Data source name (e.g., oracle, aurora, cockroach)   | `string` | n/a     |   yes    |

## Outputs

| Name                  | Description                           |
| --------------------- | ------------------------------------- |
| lambda_function_arn   | ARN of the Lambda transformer function |
| lambda_function_name  | Name of the Lambda transformer function |

## Resources Created

- `data.archive_file.transformer_zip` - Creates deployment package with Python code
- `module.dms_transformer_lambda` - Lambda function using reusable Lambda module

## Implementation Details

### Lambda Configuration

- **Runtime**: Python 3.11
- **Handler**: `index.handler`
- **Timeout**: 60 seconds
- **Memory**: 256 MB
- **IAM Role**: Basic execution role (created by Lambda module)

### Code Deployment

The module uses inline Python code deployment:

1. **Source Code**: `transformer_function.py` embedded in module
2. **Packaging**: Automatically zipped using `archive_file` data source
3. **Deployment**: Uploaded as zip file to Lambda service

### Error Handling

The transformer function handles various error scenarios:

- **Invalid JSON**: Returns `ProcessingFailed` status
- **Missing Data**: Logs warning and processes available fields
- **Transformation Errors**: Returns detailed error information
- **Empty Records**: Skips processing with appropriate status

## Connection Examples

### Firehose Integration

```hcl
# In Firehose stream configuration
processing_configuration {
  enabled = true
  processors {
    type = "Lambda"
    parameters {
      parameter_name  = "LambdaArn"
      parameter_value = module.firehose_lambda_transformer.lambda_function_arn
    }
  }
}
```

### Manual Testing

```bash
# Test the Lambda function directly
aws lambda invoke \
  --function-name ${APP}-${ENV}-${SOURCE}-firehose-lambda-transformer \
  --payload file://test-payload.json \
  response.json
```

## Troubleshooting

### Common Issues

1. **Transformation Failures**
   - Check CloudWatch logs for detailed error messages
   - Verify input data format matches expected DMS envelope structure

2. **Performance Issues**
   - Monitor Lambda duration metrics
   - Consider increasing memory allocation for large batches

3. **Deployment Issues**
   - Ensure Lambda module dependencies are available
   - Verify IAM permissions for Lambda execution

### Debugging Steps

1. **Check Lambda Logs**
   ```bash
   aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/${APP}-${ENV}"
   ```

2. **Monitor Firehose Metrics**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/KinesisFirehose \
     --metric-name DeliveryToS3.Records
   ```

3. **Test Transformation Logic**
   - Use Lambda console test events
   - Verify transformation output format

## Security Considerations

1. **IAM Permissions**
   - Lambda uses basic execution role
   - No additional permissions required for transformation
   - Firehose service handles data access

2. **Data Processing**
   - Processes data in memory only
   - No persistent storage of sensitive data
   - Logs exclude sensitive field values

3. **Network Security**
   - Runs in AWS managed VPC
   - No custom VPC configuration required
   - Secure communication with Firehose service

## Dependencies

This module requires:

- **Lambda Module**: `../lambda` for function creation
- **Archive Provider**: For zip file creation
- **Python Runtime**: Available in Lambda service
- **Firehose Service**: For integration and invocation

## Related Modules

- `../lambda`: Provides reusable Lambda function creation
- `../msk-firehose-ingestion`: Uses this transformer for DMS data processing
- `../../roots/ingestion-layer/firehose-streams/*`: Implementation examples
