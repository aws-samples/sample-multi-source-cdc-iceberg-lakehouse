# Terraform Modules

Modules are reusable infrastructure building blocks that are used by higher-level components or top-level projects. Each module encapsulates a specific piece of infrastructure and provides a clean interface through variables and outputs.

## Available Modules

### Storage Modules

- **[bucket](bucket/)**: S3 bucket with cross-region replication, encryption, and lifecycle policies
  - Primary and secondary region deployment
  - KMS encryption with customer-managed keys
  - Versioning and lifecycle management
  - Public access blocking and security configurations

### Compute Modules

- **[ec2](ec2/)**: EC2 instance with IAM role, security groups, and SSM integration

  - Configurable instance types and AMI selection
  - IAM instance profile with SSM managed instance core
  - Security group management
  - User data script support

- **[lambda](lambda/)**: Lambda function with IAM role and environment configuration
  - Configurable runtime and memory settings
  - IAM role with basic execution permissions
  - Environment variable support
  - VPC configuration options

### Database Modules

- **[aurora](aurora/)**: Aurora PostgreSQL cluster with serverless v2 configuration
  - Serverless v2 auto-scaling
  - Multi-AZ deployment options
  - Security group and subnet group management
  - Parameter group customization

### Streaming Modules


- **[msk-provisioned](msk-provisioned/)**: Amazon MSK Provisioned cluster for high-throughput Kafka streaming
  - Configurable instance types and storage capacity
  - Dual authentication support (IAM and SASL/SCRAM)
  - Multi-AZ deployment with 3-broker configuration
  - Enhanced security with KMS encryption
  - Automated topic management with EC2 configuration instance
  - DMS integration ready with SASL/SCRAM authentication

- **[msk-firehose-ingestion](msk-firehose-ingestion/)**: Kinesis Data Firehose for MSK to S3 Iceberg delivery
  - MSK source configuration with SASL authentication
  - Apache Iceberg format delivery to S3
  - Real-time data transformation using Lambda
  - CloudWatch logging and monitoring
  - Configurable buffering and compression settings

- **[firehose-lambda-transformer](firehose-lambda-transformer/)**: Lambda function for Firehose data transformation
  - Processes DMS envelope structure into flat transaction records
  - Handles MSK vs Kinesis record format differences
  - UPPERCASE to lowercase field name transformation
  - Comprehensive error handling for Firehose compatibility
  - Support for both MSK (`kafkaRecordValue`) and Kinesis (`data`) sources
  - Base64 encoding/decoding with proper response formats

### Data Catalog Modules

- **[glue-transactions-table](glue-transactions-table/)**: AWS Glue Iceberg table with financial/brokerage schemas
  - Selectable `TABLE_TYPE` (financial or brokerage) with ~200 columns each
  - `UPPERCASE_COLUMNS` flag for Oracle compatibility
  - Apache Iceberg format with typed column definitions
  - Used by both Firehose roots and Connect-path pre-created tables

### MSK Connect Modules

- **[msk-connect-debezium-source](msk-connect-debezium-source/)**: MSK Connect Debezium source connector
  - Configurable for Oracle (LogMiner) or PostgreSQL (pgoutput)
  - Custom plugin, worker config, and connector resources
  - DLQ topic configuration

### Data Migration Modules

- **[dms](dms/)**: AWS DMS replication with source endpoint, target endpoint, and task
  - Configurable for Oracle (Binary Reader) or Aurora PostgreSQL (logical replication)
  - MSK target endpoint with SASL/SCRAM authentication
  - Table mappings with schema-based selection

### Security Modules

- **[secrets-manager](secrets-manager/)**: AWS Secrets Manager secret with KMS encryption
  - KMS encryption with customer-managed keys
  - Configurable secret rotation
  - IAM policy integration
  - Cross-region replication support

## Module Standards

All modules follow these standards:

### File Structure

```
module-name/
├── README.md          # Comprehensive module documentation
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variable declarations with validation
├── outputs.tf        # Output value declarations
├── versions.tf       # Terraform and provider version constraints
└── version.tf        # Alternative naming for version constraints
```

### Variable Naming

- Use UPPERCASE for environment-specific variables (APP, ENV, REGION)
- Use descriptive names that clearly indicate the variable's purpose
- Include validation rules where appropriate
- Provide default values for optional parameters

### Output Naming

- Use descriptive names that indicate the resource and attribute
- Include both ARN and ID outputs where applicable
- Mark sensitive outputs appropriately
- Provide clear descriptions for all outputs

### Tagging

All modules apply consistent tagging:

```hcl
tags = {
  Application = var.APP
  Environment = var.ENV
  Terraform   = "true"
}
```

### Documentation

Each module includes:

- **Overview**: Purpose and functionality
- **Architecture**: Visual representation where helpful
- **Usage**: Basic and advanced examples
- **Variables**: Complete table with descriptions, types, and defaults
- **Outputs**: Complete table with descriptions
- **Dependencies**: Prerequisites and related modules
- **Examples**: Real-world usage scenarios

## Usage Patterns

### Basic Module Usage

```hcl
module "example" {
  source = "../../../templates/modules/module-name"

  APP = var.APP
  ENV = var.ENV

  # Module-specific variables
  INSTANCE_TYPE = "t3.micro"
  SUBNET_IDS    = data.aws_subnets.private.ids
}
```

### Module with Conditional Resources

```hcl
module "conditional_example" {
  source = "../../../templates/modules/module-name"

  APP = var.APP
  ENV = var.ENV

  # Conditional deployment
  CREATE_RESOURCE = var.ENV == "prod" ? true : false

  # Environment-specific sizing
  INSTANCE_TYPE = var.ENV == "prod" ? "m5.large" : "t3.micro"
}
```

### Module Integration

```hcl
# Primary module
module "database" {
  source = "../../../templates/modules/aurora"

  APP = var.APP
  ENV = var.ENV

  SUBNET_IDS         = data.aws_subnets.private.ids
  SECURITY_GROUP_IDS = [aws_security_group.db_sg.id]
}

# Dependent module using outputs
module "application" {
  source = "../../../templates/modules/ec2"

  APP = var.APP
  ENV = var.ENV

  SUBNET_ID = data.aws_subnets.private.ids[0]

  # Use database module outputs
  USER_DATA = templatefile("user_data.sh", {
    DB_ENDPOINT = module.database.cluster_endpoint
    DB_PORT     = module.database.cluster_port
  })
}
```

## Module Details

### Data Transformation Modules

#### firehose-lambda-transformer

The `firehose-lambda-transformer` module provides a specialized Lambda function designed for transforming data in Amazon Kinesis Data Firehose pipelines, particularly for DMS (Database Migration Service) envelope processing.

**Key Features:**
- **DMS Envelope Processing**: Extracts transaction data from DMS envelope structure (ignores metadata for flat schema)
- **Field Name Transformation**: Converts UPPERCASE DMS field names to lowercase for AWS Glue compatibility
- **Multi-Source Support**: Handles both MSK (`kafkaRecordValue`) and Kinesis Data Streams (`data`) record formats
- **Error Handling**: Comprehensive error handling with proper Firehose response codes (`Ok`, `ProcessingFailed`)
- **Base64 Processing**: Automatic encoding/decoding for Firehose compatibility
- **Logging**: Detailed CloudWatch logging for monitoring and troubleshooting

**Use Cases:**
- Processing Oracle DMS data from MSK to S3 Iceberg format
- Real-time data transformation in streaming pipelines
- Converting nested DMS structures to flat transaction records
- Handling different Kinesis source types in a single function

**Example Input (DMS Envelope):**
```json
{
  "data": {
    "TRANSACTION_ID": "TXN123",
    "CUSTOMER_ID": "CUST456",
    "TRANSACTION_AMOUNT": 100.50
  },
  "metadata": {
    "timestamp": "2025-07-29T17:14:11.899843Z",
    "record-type": "data",
    "operation": "insert"
  }
}
```

**Example Output (Flat Record):**
```json
{
  "transaction_id": "TXN123",
  "customer_id": "CUST456", 
  "transaction_amount": 100.50
}
```

#### msk-firehose-ingestion

The `msk-firehose-ingestion` module creates a complete Amazon Kinesis Data Firehose pipeline for consuming data from Amazon MSK clusters and delivering it to S3 in Apache Iceberg format.

**Key Features:**
- **MSK Source Configuration**: Connects to MSK clusters with SASL authentication
- **Apache Iceberg Delivery**: Direct delivery to S3 in Iceberg table format
- **Lambda Transformation**: Integration with firehose-lambda-transformer for data processing
- **CloudWatch Monitoring**: Comprehensive logging and monitoring capabilities
- **IAM Security**: Least-privilege IAM roles and policies
- **Lake Formation Integration**: Automatic permissions for Glue catalog access

## Best Practices

### Module Development

1. **Single Responsibility**: Each module should have a clear, single purpose
2. **Reusability**: Design modules to be reusable across different environments
3. **Validation**: Include input validation to catch configuration errors early
4. **Documentation**: Maintain comprehensive documentation with examples
5. **Testing**: Test modules in multiple scenarios and environments

### Module Consumption

1. **Version Pinning**: Use specific module versions in production
2. **Variable Validation**: Validate inputs at the calling level
3. **Output Usage**: Use module outputs rather than hardcoded values
4. **Error Handling**: Plan for module failures and rollback scenarios
5. **Security**: Review module security implications before deployment

### Security Considerations

1. **Least Privilege**: Grant minimal required permissions
2. **Encryption**: Enable encryption for data at rest and in transit
3. **Network Security**: Use security groups and NACLs appropriately
4. **Secrets Management**: Use AWS Secrets Manager for sensitive data
5. **Audit Logging**: Enable CloudTrail and other audit mechanisms

## Contributing

When contributing new modules or updating existing ones:

1. Follow the established file structure and naming conventions
2. Include comprehensive documentation with examples
3. Add appropriate variable validation and default values
4. Test the module in multiple scenarios
5. Update this README to include the new module
6. Follow the tagging standards for all resources

## Dependencies

Modules may depend on:

- **Foundation Modules**: Network, IAM, KMS infrastructure
- **AWS Services**: Specific AWS service availability
- **Terraform Providers**: Minimum provider versions
- **External Resources**: VPCs, subnets, security groups created elsewhere

Check individual module documentation for specific dependencies and prerequisites.
