# Secrets Manager Module

This Terraform module creates AWS Secrets Manager secrets with configurable KMS encryption, recovery windows, and automatic versioning for secure credential storage in the Iceberg data lakehouse infrastructure.

## Features

- **Secure Storage**: Encrypted secret storage with customer-managed or AWS-managed KMS keys
- **Automatic Versioning**: Creates secret versions with provided secret strings
- **Configurable Recovery**: Flexible recovery window settings (0 for immediate deletion, 7-30 days)
- **KMS Integration**: Optional customer-managed KMS key encryption
- **Standardized Naming**: Consistent naming convention with APP and ENV prefixes
- **Development Optimized**: Default immediate deletion for development environments

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│  Secrets Manager    │    │    KMS Encryption   │    │   Applications      │
│                     │    │                     │    │                     │
│ • Secret Storage    │◄───┤ • Customer Keys     │◄───┤ • Database Clients  │
│ • Version Control   │    │ • AWS Managed Keys  │    │ • API Credentials   │
│ • Recovery Window   │    │ • Access Control    │    │ • Service Tokens    │
│ • Access Policies   │    │                     │    │                     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Usage

### Basic Secret Storage

```hcl
module "database_password" {
  source = "../../templates/modules/secrets-manager"

  APP           = "${APP_NAME}"
  ENV           = "prod"
  SECRET_NAME   = "database-password"  # pragma: allowlist secret
  SECRET_STRING = "MySecurePassword123!"  # pragma: allowlist secret
}
```

### Secret with Custom KMS Key

```hcl
module "api_credentials" {
  source = "../../templates/modules/secrets-manager"

  APP             = "${APP_NAME}"
  ENV             = "prod"
  SECRET_NAME     = "api-credentials"  # pragma: allowlist secret
  SECRET_STRING   = jsonencode({
    username = "api_user"
    password = "SecureApiPassword123!"  # pragma: allowlist secret
    endpoint = "https://api.example.com"
  })
  KMS_KEY_ARN     = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  RECOVERY_WINDOW = 30
}
```

### MSK Cluster Credentials

```hcl
module "msk_credentials" {
  source = "../../templates/modules/secrets-manager"

  APP           = var.APP
  ENV           = var.ENV
  SECRET_NAME   = "msk-cluster-credentials"  # pragma: allowlist secret
  SECRET_STRING = jsonencode({
    username = "kafka-admin"
    password = random_password.msk_password.result  # pragma: allowlist secret
  })
  KMS_KEY_ARN     = data.aws_kms_key.secrets_manager_key.arn
  RECOVERY_WINDOW = 7
}
```

### Bootstrap Server Endpoints

```hcl
module "msk_bootstrap_servers" {
  source = "../../templates/modules/secrets-manager"

  APP           = var.APP
  ENV           = var.ENV
  SECRET_NAME   = "msk-bootstrap-servers-sasl-scram"  # pragma: allowlist secret
  SECRET_STRING = "broker1:9096,broker2:9096,broker3:9096"  # pragma: allowlist secret
}
```

### Development Environment Secret

```hcl
module "dev_secret" {
  source = "../../templates/modules/secrets-manager"

  APP             = "${APP_NAME}"
  ENV             = "dev"
  SECRET_NAME     = "test-credentials"  # pragma: allowlist secret
  SECRET_STRING   = "development-password"  # pragma: allowlist secret
  RECOVERY_WINDOW = 0  # Immediate deletion for dev
}
```

## Inputs

| Name            | Description                                    | Type     | Default | Required |
| --------------- | ---------------------------------------------- | -------- | ------- | :------: |
| APP             | Application name for resource naming           | `string` | n/a     |   yes    |
| ENV             | Environment name                               | `string` | n/a     |   yes    |
| SECRET_NAME     | Name prefix of the secret                      | `string` | n/a     |   yes    |
| SECRET_STRING   | Secret string to be stored                     | `string` | n/a     |   yes    |
| RECOVERY_WINDOW | Recovery window in days (0 or 7-30)           | `number` | `0`     |    no    |
| KMS_KEY_ARN     | ARN of KMS key for encryption                  | `string` | `null`  |    no    |

### Recovery Window Options

- **`0`**: Immediate deletion without recovery (default for development)
- **`7-30`**: Recovery window in days for production environments
- **Production Recommendation**: Use 30 days for maximum recovery flexibility

## Outputs

| Name        | Description                    |
| ----------- | ------------------------------ |
| arn         | ARN of the created secret      |
| secret_name | Full name of the created secret |

## Secret Naming Convention

Secrets are named using the pattern: `{APP}-{ENV}-{SECRET_NAME}`

**Examples:**
- `${APP_NAME}-prod-database-password`  # pragma: allowlist secret
- `${APP_NAME}-dev-api-credentials`
- `${APP_NAME}-${ENV_NAME}-msk-cluster-credentials`

## Security Considerations

### KMS Encryption

**AWS Managed Key (Default):**
- Uses `aws/secretsmanager` key
- No additional cost
- AWS-managed key rotation

**Customer Managed Key:**
- Full control over key policies
- Custom key rotation schedules
- Additional KMS charges apply
- Enhanced audit capabilities

### Access Control

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/MyApplicationRole"
      },
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "secretsmanager:ResourceTag/Application": "${APP_NAME}",
          "secretsmanager:ResourceTag/Environment": "prod"
        }
      }
    }
  ]
}
```

### Best Practices

1. **Use Customer-Managed KMS Keys** for production environments
2. **Set Appropriate Recovery Windows** (30 days for production, 0 for development)
3. **Implement Least Privilege Access** with resource-based policies
4. **Regular Secret Rotation** for long-lived credentials
5. **Audit Secret Access** through CloudTrail logs

## Common Use Cases

### Database Credentials

```hcl
module "rds_credentials" {
  source = "../../templates/modules/secrets-manager"

  APP           = var.APP
  ENV           = var.ENV
  SECRET_NAME   = "rds-master-credentials"  # pragma: allowlist secret
  SECRET_STRING = jsonencode({
    username = "admin"
    password = random_password.rds_password.result  # pragma: allowlist secret
    engine   = "postgres"
    host     = aws_rds_cluster.main.endpoint
    port     = 5432
    dbname   = "equitydb"
  })
  KMS_KEY_ARN     = data.aws_kms_key.rds_key.arn
  RECOVERY_WINDOW = 30
}
```

### API Keys and Tokens

```hcl
module "external_api_key" {
  source = "../../templates/modules/secrets-manager"

  APP           = var.APP
  ENV           = var.ENV
  SECRET_NAME   = "external-api-key"  # pragma: allowlist secret
  SECRET_STRING = jsonencode({
    api_key    = var.external_api_key
    secret_key = var.external_secret_key  # pragma: allowlist secret
    base_url   = "https://api.external-service.com"
  })
  RECOVERY_WINDOW = 30
}
```

### Service-to-Service Authentication

```hcl
module "service_token" {
  source = "../../templates/modules/secrets-manager"

  APP           = var.APP
  ENV           = var.ENV
  SECRET_NAME   = "service-auth-token"  # pragma: allowlist secret
  SECRET_STRING = jsonencode({
    token      = random_uuid.service_token.result
    expires_at = timeadd(timestamp(), "8760h") # 1 year
    service    = "data-processor"
  })
}
```

## Integration Examples

### Lambda Function Access

```python
import boto3
import json

def get_secret(secret_name):
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])

def lambda_handler(event, context):
    # Retrieve database credentials
    db_creds = get_secret('${APP_NAME}-prod-database-password')  # pragma: allowlist secret
    
    # Use credentials to connect to database
    connection = connect_to_database(
        host=db_creds['host'],
        username=db_creds['username'],
        password=db_creds['password']  # pragma: allowlist secret
    )
```

### DMS Integration

```hcl
# DMS uses secrets for source database authentication
data "aws_secretsmanager_secret_version" "oracle_password" {  # pragma: allowlist secret
  secret_id = module.oracle_credentials.arn
}

resource "aws_dms_endpoint" "source" {
  endpoint_id   = "oracle-source"
  endpoint_type = "source"
  engine_name   = "oracle"
  
  username = "SYSTEM"
  password = jsondecode(data.aws_secretsmanager_secret_version.oracle_password.secret_string)["password"]  # pragma: allowlist secret
  
  server_name   = var.oracle_host
  port          = 1521
  database_name = var.oracle_pdb
}
```

### MSK SASL/SCRAM Authentication

```hcl
# MSK cluster uses secrets for SASL/SCRAM authentication
resource "aws_msk_scram_secret_association" "main" {
  cluster_arn     = aws_msk_cluster.main.arn
  secret_arn_list = [module.msk_credentials.arn]
}
```

## Monitoring and Alerting

### CloudWatch Metrics

Monitor secret usage with CloudWatch:
- `AWS/SecretsManager/SecretRetrievals`
- `AWS/SecretsManager/RotationFailed`
- `AWS/SecretsManager/RotationSucceeded`

### CloudTrail Events

Track secret access through CloudTrail:
- `GetSecretValue`
- `CreateSecret`
- `UpdateSecret`
- `DeleteSecret`

## Dependencies

This module requires:

- **Terraform**: >= 1.8.0
- **AWS Provider**: >= 5.0
- **IAM Permissions**:
  - `secretsmanager:CreateSecret`
  - `secretsmanager:PutSecretValue`
  - `secretsmanager:TagResource`
  - `kms:Encrypt` (if using customer-managed KMS key)
  - `kms:Decrypt` (if using customer-managed KMS key)

## Related Modules

- `../msk-provisioned`: Uses secrets for SASL/SCRAM authentication
- `../aurora`: Stores database credentials in secrets
- `../lambda`: Retrieves secrets for application configuration
- `../../foundation/kms-keys`: Provides KMS keys for secret encryption
