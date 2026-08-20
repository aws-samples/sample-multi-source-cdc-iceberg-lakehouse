# Lambda Function Module

This Terraform module creates AWS Lambda functions with comprehensive configuration options, automatic IAM role management, VPC support, and flexible deployment methods for serverless computing in the Iceberg data lakehouse.

## Features

- **Flexible Deployment**: Support for both zip file and S3 bucket deployment methods
- **Automatic IAM Management**: Creates IAM roles with customizable policies and managed policy attachments
- **VPC Integration**: Optional VPC configuration with subnet and security group support
- **CloudWatch Integration**: Automatic log group creation with JSON logging format
- **Runtime Support**: Supports all major AWS Lambda runtimes (Python, Node.js, Java, .NET, Go, Ruby)
- **Environment Variables**: Configurable environment variables for function configuration
- **Concurrency Control**: Configurable reserved concurrent executions
- **Layer Support**: Lambda layer integration for shared code and dependencies

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Lambda Function   │    │    IAM Role         │    │   CloudWatch        │
│                     │    │                     │    │                     │
│ • Runtime Support   │◄───┤ • Execution Role    │    │ • Log Groups        │
│ • Environment Vars  │    │ • Custom Policies   │    │ • JSON Logging      │
│ • VPC Configuration │    │ • Managed Policies  │    │ • 30-day Retention  │
│ • Layer Integration │    │ • VPC Permissions   │    │                     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Usage

### Basic Lambda Function

```hcl
module "data_processor" {
  source = "../../templates/modules/lambda"

  APP           = "${APP_NAME}"
  ENV           = "prod"
  function_name = "data-processor"
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  
  source_code_path = "./src/data-processor"
  
  environment_variables = {
    LOG_LEVEL = "INFO"
    REGION    = "us-east-1"
  }
}
```

### Lambda with Custom IAM Policies

```hcl
module "s3_processor" {
  source = "../../templates/modules/lambda"

  APP           = "${APP_NAME}"
  ENV           = "prod"
  function_name = "s3-processor"
  runtime       = "python3.11"
  
  source_code_path = "./src/s3-processor"
  
  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = [
        "arn:aws:s3:::my-data-bucket/*"
      ]
      condition = null
    }
  ]
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]
}
```

### Lambda with VPC Configuration

```hcl
module "vpc_lambda" {
  source = "../../templates/modules/lambda"

  APP           = "${APP_NAME}"
  ENV           = "prod"
  function_name = "vpc-processor"
  runtime       = "python3.11"
  
  source_code_path = "./src/vpc-processor"
  
  subnet_ids = [
    "subnet-12345678",
    "subnet-87654321"
  ]
  
  security_group_ids = [
    "sg-abcdef123"
  ]
  
  timeout     = 300
  memory_size = 512
}
```

### Lambda with S3 Deployment

```hcl
module "s3_deployed_lambda" {
  source = "../../templates/modules/lambda"

  APP           = "${APP_NAME}"
  ENV           = "prod"
  function_name = "s3-deployed-function"
  runtime       = "java11"
  handler       = "com.example.Handler::handleRequest"
  
  deployment_method = "s3_bucket"
  s3_bucket         = "my-lambda-deployments"
  s3_key           = "functions/my-function.jar"
  
  memory_size = 1024
  timeout     = 900
}
```

### Lambda with Existing IAM Role

```hcl
module "existing_role_lambda" {
  source = "../../templates/modules/lambda"

  APP           = "${APP_NAME}"
  ENV           = "prod"
  function_name = "existing-role-function"
  runtime       = "nodejs20.x"
  
  create_role = false
  role_arn    = "arn:aws:iam::123456789012:role/existing-lambda-role"
  
  source_code_path = "./src/nodejs-function"
}
```

## Inputs

| Name                          | Description                                    | Type           | Default                | Required |
| ----------------------------- | ---------------------------------------------- | -------------- | ---------------------- | :------: |
| APP                           | Application name for resource naming           | `string`       | n/a                    |   yes    |
| ENV                           | Environment name                               | `string`       | n/a                    |   yes    |
| function_name                 | Name of the Lambda function                    | `string`       | n/a                    |   yes    |
| runtime                       | Lambda runtime                                 | `string`       | `"python3.11"`         |    no    |
| handler                       | Lambda function handler                        | `string`       | `"handler.lambda_handler"` |    no    |
| timeout                       | Function timeout in seconds (1-900)           | `number`       | `30`                   |    no    |
| memory_size                   | Function memory size in MB (128-10240)        | `number`       | `256`                  |    no    |
| source_code_path              | Path to source code directory                  | `string`       | `null`                 |    no    |
| zip_file_path                 | Path to zip file containing Lambda code       | `string`       | `null`                 |    no    |
| deployment_method             | Deployment method (zip_file or s3_bucket)     | `string`       | `"zip_file"`           |    no    |
| s3_bucket                     | S3 bucket for deployment package              | `string`       | `null`                 |    no    |
| s3_key                        | S3 key of deployment package                  | `string`       | `null`                 |    no    |
| s3_object_version             | S3 object version of deployment package       | `string`       | `null`                 |    no    |
| environment_variables         | Environment variables for the function        | `map(string)`  | `{}`                   |    no    |
| create_role                   | Whether to create an IAM role                 | `bool`         | `true`                 |    no    |
| role_arn                      | Existing IAM role ARN (if create_role=false)  | `string`       | `null`                 |    no    |
| policy_statements             | Additional IAM policy statements              | `list(object)` | `[]`                   |    no    |
| managed_policy_arns           | List of managed policy ARNs to attach        | `list(string)` | `[]`                   |    no    |
| reserved_concurrent_executions | Reserved concurrent executions (-1=unlimited) | `number`       | `-1`                   |    no    |
| layers                        | List of Lambda layer ARNs                     | `list(string)` | `[]`                   |    no    |
| subnet_ids                    | List of subnet IDs for VPC configuration      | `list(string)` | `[]`                   |    no    |
| security_group_ids            | List of security group IDs for VPC config     | `list(string)` | `[]`                   |    no    |
| exclude                       | Files to exclude from zip deployment          | `list(string)` | `[]`                   |    no    |

## Outputs

| Name          | Description                        |
| ------------- | ---------------------------------- |
| function_name | Name of the Lambda function        |
| function_arn  | ARN of the Lambda function         |
| role_arn      | ARN of the IAM role (if created)   |
| role_name     | Name of the IAM role (if created)  |
| log_group_arn | ARN of the CloudWatch log group    |

## Supported Runtimes

### Python
- `python3.8`, `python3.9`, `python3.10`, `python3.11`, `python3.12`

### Node.js
- `nodejs18.x`, `nodejs20.x`

### Java
- `java8`, `java11`, `java17`, `java21`

### .NET
- `dotnet6`, `dotnet8`

### Go
- `go1.x`

### Ruby
- `ruby3.2`, `ruby3.3`

## Deployment Methods

### Zip File Deployment (Default)

**From Source Directory:**
```hcl
source_code_path = "./src/my-function"
```

**From Existing Zip:**
```hcl
zip_file_path = "./deployments/my-function.zip"
```

### S3 Bucket Deployment

```hcl
deployment_method = "s3_bucket"
s3_bucket         = "my-deployment-bucket"
s3_key           = "functions/my-function.zip"
s3_object_version = "version123"  # Optional
```

## IAM Policy Configuration

### Custom Policy Statements

```hcl
policy_statements = [
  {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ]
    resources = [
      "arn:aws:dynamodb:us-east-1:123456789012:table/MyTable"
    ]
    condition = {
      StringEquals = {
        test     = "StringEquals"
        variable = "dynamodb:LeadingKeys"
        values   = ["user123"]
      }
    }
  }
]
```

### Managed Policy Attachments

```hcl
managed_policy_arns = [
  "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
]
```

## VPC Configuration

When both `subnet_ids` and `security_group_ids` are provided:

- Lambda function is deployed in VPC
- Automatic attachment of `AWSLambdaVPCAccessExecutionRole` policy
- Enhanced security with private subnet deployment
- Access to VPC resources (RDS, ElastiCache, etc.)

## CloudWatch Integration

### Automatic Log Group Creation

- Log group: `/aws/lambda/{function-name}`
- Retention: 30 days
- Format: JSON for structured logging
- Application log level: INFO

### Logging Configuration

```python
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(json.dumps({
        "event": event,
        "context": {
            "request_id": context.aws_request_id,
            "function_name": context.function_name
        }
    }))
```

## Performance Optimization

### Memory and Timeout Configuration

- **Memory**: 128MB - 10,240MB (affects CPU allocation)
- **Timeout**: 1 - 900 seconds
- **Concurrency**: Configurable reserved executions

### Layer Usage

```hcl
layers = [
  "arn:aws:lambda:us-east-1:123456789012:layer:my-shared-layer:1",
  "arn:aws:lambda:us-east-1:580247275435:layer:LambdaInsightsExtension:14"
]
```

## Integration Examples

### Firehose Data Transformation

```hcl
module "firehose_transformer" {
  source = "../../templates/modules/lambda"

  APP           = var.APP
  ENV           = var.ENV
  function_name = "firehose-transformer"
  runtime       = "python3.11"
  
  source_code_path = "./src/firehose-transformer"
  
  environment_variables = {
    LOG_LEVEL = "INFO"
  }
  
  timeout     = 60
  memory_size = 512
}
```

### MSK Event Processing

```hcl
module "msk_processor" {
  source = "../../templates/modules/lambda"

  APP           = var.APP
  ENV           = var.ENV
  function_name = "msk-processor"
  runtime       = "python3.11"
  
  source_code_path = "./src/msk-processor"
  
  subnet_ids = var.private_subnet_ids
  security_group_ids = [var.lambda_sg_id]
  
  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "kafka:DescribeCluster",
        "kafka:GetBootstrapBrokers"
      ]
      resources = ["*"]
      condition = null
    }
  ]
}
```

## Dependencies

This module requires:

- **Terraform**: >= 1.8.0
- **AWS Provider**: >= 5.0
- **IAM Permissions**:
  - Lambda function management
  - IAM role creation (if create_role=true)
  - CloudWatch logs creation
  - VPC access (if VPC configuration used)

## Related Modules

- `../msk-firehose-ingestion`: Uses Lambda for data transformation
- `../glue-transactions-table`: Lambda processes data for Glue tables
- `../secrets-manager`: Lambda retrieves configuration from secrets
- `../../foundation/network`: Provides VPC configuration for Lambda
