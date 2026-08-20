# MSK Provisioned Cluster Module

This Terraform module creates an Amazon MSK (Managed Streaming for Apache Kafka) provisioned cluster with comprehensive security, monitoring, and authentication features.

## Features

- **Dual Authentication**: Supports both IAM and SASL/SCRAM authentication methods with VPC connectivity
- **Comprehensive Encryption**: Data encryption at rest and in transit using customer-managed KMS keys
- **Advanced Monitoring**: CloudWatch logs and Prometheus monitoring with JMX and Node exporters
- **Secure Credential Management**: Automatic password generation and secure storage in AWS Secrets Manager
- **Flexible Networking**: Supports 2-3 subnets with automatic subnet selection and VPC connectivity
- **Enhanced Security**: Integration with AWS Secrets Manager using properly named secrets for MSK registration
- **VPC Connectivity**: Configurable SASL authentication within VPC for secure internal communication

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   MSK Cluster       │    │  Secrets Manager    │    │   CloudWatch        │
│                     │    │                     │    │                     │
│ • SASL/SCRAM Auth   │◄───┤ • Auto-generated    │    │ • Broker Logs       │
│ • IAM Auth          │    │   passwords         │    │ • Prometheus        │
│ • VPC Connectivity  │    │ • KMS Encrypted     │    │   Metrics           │
│ • TLS Encryption    │    │ • AmazonMSK_ prefix │    │ • JMX Exporter      │
│ • EBS Storage       │    │                     │    │                     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Usage

```hcl
module "msk_cluster" {
  source = "../../../templates/modules/msk-provisioned"

  # Required variables
  APP                         = "myapp"
  ENV                         = "dev"
  CLUSTER_NAME                = "data-streaming"
  SUBNET_IDS                  = ["subnet-12345", "subnet-67890", "subnet-abcdef"]
  SECURITY_GROUP_IDS          = ["sg-abcdef123"]

  # Required: KMS keys for encryption (from foundation layer)
  KAFKA_KMS_KEY_ARN           = data.aws_kms_key.msk_key.arn
  SECRETS_MANAGER_KMS_KEY_ARN = data.aws_kms_key.secrets_manager_key.arn

  # Optional: Kafka configuration
  KAFKA_VERSION               = "3.9.1"
  INSTANCE_TYPE               = "kafka.m5.large"
  STORAGE_SIZE                = 1000
  ENHANCED_MONITORING_LEVEL   = "PER_TOPIC_PER_PARTITION"

  # Optional: SASL/SCRAM Authentication
  ENABLE_SASL_SCRAM_AUTH      = true
  SASL_SCRAM_USERNAME         = "kafka-admin"
}
```

## Authentication Methods

### SASL/SCRAM Authentication

When `ENABLE_SASL_SCRAM_AUTH = true` and credentials are provided:

- Creates AWS Secrets Manager secret with username/password
- Associates secret with MSK cluster for SASL/SCRAM authentication
- Configures VPC connectivity with SASL authentication support
- Use `bootstrap_brokers_sasl_scram` output for connections

### IAM Authentication

Always enabled alongside SASL/SCRAM:

- Configured for both client authentication and VPC connectivity
- Use `bootstrap_brokers_sasl_iam` output for IAM-based connections

### VPC Connectivity Configuration

The module configures VPC connectivity with client authentication that supports:

- **IAM Authentication**: Always enabled for secure AWS service integration
- **SASL/SCRAM Authentication**: Enabled when `ENABLE_SASL_SCRAM_AUTH` is true
- **Public Access**: Disabled by default for enhanced security

## Inputs

| Name                        | Description                                 | Type           | Default                     | Required |
| --------------------------- | ------------------------------------------- | -------------- | --------------------------- | :------: |
| APP                         | Application name                            | `string`       | n/a                         |   yes    |
| ENV                         | Environment name                            | `string`       | n/a                         |   yes    |
| CLUSTER_NAME                | Name of the cluster                         | `string`       | n/a                         |   yes    |
| SUBNET_IDS                  | List of subnet IDs (2-3 subnets supported)  | `list(string)` | n/a                         |   yes    |
| SECURITY_GROUP_IDS          | List of security group IDs                  | `list(string)` | n/a                         |   yes    |
| KAFKA_KMS_KEY_ARN           | KMS key ARN for Kafka encryption (required) | `string`       | n/a                         |   yes    |
| SECRETS_MANAGER_KMS_KEY_ARN | KMS key ARN for Secrets Manager encryption  | `string`       | n/a                         |   yes    |
| KAFKA_VERSION               | Kafka version to use                        | `string`       | `"3.9.1"`                   |    no    |
| INSTANCE_TYPE               | Type of instance for cluster nodes          | `string`       | `"kafka.m5.large"`          |    no    |
| STORAGE_SIZE                | Size of storage in GiB                      | `number`       | `1000`                      |    no    |
| ENHANCED_MONITORING_LEVEL   | Level of enhanced monitoring                | `string`       | `"PER_TOPIC_PER_PARTITION"` |    no    |
| ENABLE_SASL_SCRAM_AUTH      | Enable SASL/SCRAM authentication            | `bool`         | `true`                      |    no    |
| SASL_SCRAM_USERNAME         | Username for SASL/SCRAM authentication      | `string`       | `"admin"`                   |    no    |

## Outputs

| Name                         | Description                                   |
| ---------------------------- | --------------------------------------------- |
| cluster_arn                  | Amazon Resource Name (ARN) of the MSK cluster |
| cluster_name                 | Name of the MSK cluster                       |
| bootstrap_brokers_tls        | TLS connection host:port pairs                |
| bootstrap_brokers_sasl_scram | SASL/SCRAM connection host:port pairs         |
| bootstrap_brokers_sasl_iam   | SASL/IAM connection host:port pairs           |
| zookeeper_connect_string     | Zookeeper connection string                   |
| kms_key_arn                  | ARN of the KMS key used for encryption        |
| secrets_manager_secret_arn   | ARN of the Secrets Manager secret             |
| cloudwatch_log_group_name    | Name of the CloudWatch log group              |

## Implementation Details

### VPC Connectivity Configuration

The module configures VPC connectivity with enhanced security features:

```hcl
connectivity_info {
  public_access {
    type = "DISABLED"
  }
  vpc_connectivity {
    client_authentication {
      sasl {
        iam   = true
        scram = var.ENABLE_SASL_SCRAM_AUTH
      }
    }
  }
}
```

This configuration ensures:

- Public access is disabled for security
- VPC-only connectivity for internal communication
- Dual authentication support (IAM + SASL/SCRAM)
- Configurable SASL/SCRAM authentication based on module variables

### Automatic Password Generation

The module automatically generates secure passwords for SASL/SCRAM authentication when `ENABLE_SASL_SCRAM_AUTH` is enabled:

- 16-character passwords with mixed case, numbers, and special characters
- Stored securely in AWS Secrets Manager with KMS encryption
- Passwords are marked as sensitive in Terraform state

### Secrets Manager Integration

The module creates AWS Secrets Manager secrets with specific naming conventions required by MSK:

- Secret names must start with `AmazonMSK_` for automatic MSK registration
- Secrets are encrypted using customer-managed KMS keys
- Secret policies allow MSK service access for SASL/SCRAM authentication
- Immediate deletion enabled (recovery_window_in_days = 0) for development environments

### Subnet Selection Logic

MSK clusters support 2-3 subnets for high availability:

```hcl
locals {
  # MSK only accepts 2 or 3 subnets, so take the first 3 if we have more than 3
  MSK_SUBNETS = length(var.SUBNET_IDS) > 3 ? slice(var.SUBNET_IDS, 0, 3) : var.SUBNET_IDS
}
```

### Monitoring Configuration

The module enables comprehensive monitoring:

- **CloudWatch Logs**: Broker logs with 7-day retention
- **Prometheus Metrics**: JMX and Node exporters enabled
- **Enhanced Monitoring**: Configurable level (default: PER_TOPIC_PER_PARTITION)

## Connection Examples

### SASL/SCRAM Connection

```bash
# Using Kafka CLI tools
kafka-console-producer.sh \
  --bootstrap-server <bootstrap_brokers_sasl_scram> \
  --topic my-topic \
  --producer.config sasl.properties
```

Where `sasl.properties` contains:

```properties
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="<username>" \
  password="<password>";
```

### IAM Authentication Connection

```bash
# Using IAM authentication
kafka-console-producer.sh \
  --bootstrap-server <bootstrap_brokers_sasl_iam> \
  --topic my-topic \
  --producer.config iam.properties
```

Where `iam.properties` contains:

```properties
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
```

## Troubleshooting

### Common Issues

1. **Secret Name Conflicts**

   - Error: Secret with name already exists
   - Solution: Ensure unique cluster names or manually delete existing secrets

2. **Subnet Configuration**

   - Error: Invalid number of subnets
   - Solution: Provide 2-3 subnets in different AZs

3. **KMS Key Permissions**
   - Error: Access denied to KMS key
   - Solution: Ensure MSK service has decrypt permissions on KMS keys

### Debugging Steps

1. **Check MSK Cluster Status**

   ```bash
   aws kafka describe-cluster --cluster-arn <cluster_arn>
   ```

2. **Verify Secret Association**

   ```bash
   aws kafka list-scram-secrets --cluster-arn <cluster_arn>
   ```

3. **Check CloudWatch Logs**
   ```bash
   aws logs describe-log-groups --log-group-name-prefix "/<app>/<env>/msk/"
   ```

## Security Considerations

1. **Credentials Management**

   - SASL/SCRAM passwords are automatically generated and marked as sensitive
   - Passwords are stored in AWS Secrets Manager with KMS encryption
   - Secret policies restrict access to MSK service only

2. **Encryption**

   - Data encrypted at rest using customer-managed KMS keys
   - Data encrypted in transit using TLS
   - Inter-broker communication encrypted

3. **Network Security**

   - Deploy in private subnets with appropriate security groups
   - Restrict access to necessary ports (9092, 9094, 9098)
   - Use VPC endpoints for AWS service communication

4. **Access Control**

   - Use IAM policies for fine-grained access control
   - Implement least privilege principle
   - Monitor access through CloudTrail
   - VPC connectivity ensures internal-only access

5. **Network Isolation**
   - Public access disabled by default
   - VPC connectivity for secure internal communication
   - Configurable authentication methods within VPC

## Dependencies

This module requires:

- **Terraform**: >= 1.0
- **AWS Provider**: >= 5.0
- **Foundation Layer**: KMS keys module must be deployed first
- **Network Layer**: VPC and subnets must exist
- **IAM Permissions**:
  - MSK cluster management
  - Secrets Manager read/write
  - KMS encrypt/decrypt
  - CloudWatch logs creation

## Related Modules

- `../../foundation/kms-keys`: Provides required KMS keys
- `../../foundation/network`: Provides VPC and subnets
