# MSK Data Source Module

## Overview

This module provisions Amazon MSK (Managed Streaming for Apache Kafka) infrastructure as a data source for the Iceberg Data Lakehouse project. It creates a provisioned MSK cluster that serves as a primary streaming data source, receiving data from Lambda functions and other streaming applications.

## Architecture

The MSK data source module creates the following components:

```
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐
│   Data Generator    │───▶│  MSK Source          │───▶│  AWS Glue           │
│   Lambda Functions  │    │  Cluster             │    │  Streaming Jobs     │
│                     │    │                      │    │                     │
│ • Scheduled Events  │    │ • Provisioned MSK    │    │ • Stream Processing │
│ • Streaming Data    │    │ • Auto Scaling       │    │ • Data Transform    │
│ • Real-time Events  │    │ • Private Subnets    │    │ • S3 Delivery       │
└─────────────────────┘    └──────────────────────┘    └─────────────────────┘
                                      │
                                      ▼
                           ┌──────────────────────┐
                           │   Amazon Data        │
                           │   Firehose           │
                           │                      │
                           │ • Stream Buffering   │
                           │ • Format Conversion  │
                           │ • S3 Iceberg Output  │
                           └──────────────────────┘
```

## Features

- **Provisioned MSK Cluster**: Dedicated Kafka cluster for streaming data sources
- **Security Groups**: Dedicated security groups for MSK cluster and EC2 management clients
- **VPC Integration**: Deployed in private subnets with proper network isolation
- **High Availability**: Multi-AZ deployment for fault tolerance
- **Management EC2**: Optional EC2 instance for Kafka topic management and monitoring

## Resources Created

### MSK Cluster

- **Name**: `${APP}-${ENV}-msk-cluster`
- **Type**: Provisioned MSK cluster using the msk-provisioned module template
- **Deployment**: Private subnets across multiple AZs
- **Authentication**: SASL/IAM for AWS service integration
- **Security**: Dedicated security groups for access control

### Security Groups

- **MSK Security Group**: `${APP}-${ENV}-msk-sg`
  - Allows TCP traffic from VPC CIDR (ports 0-65535)
  - Allows all traffic from EC2 client security group
  - Allows DMS connections on port 9098 for SASL/IAM
- **EC2 Security Group**: `${APP}-${ENV}-ec2-sg`
  - Allows self-referencing traffic for cluster communication
  - Allows all outbound traffic

### Management EC2 Instance

- **Name**: `${APP}-${ENV}-msk-config`
- **Purpose**: Kafka topic management and cluster configuration
- **Deployment**: Public subnet for management access
- **IAM Role**: Comprehensive MSK permissions for cluster management

## Prerequisites

Before deploying this module, ensure the following resources exist:

1. **VPC and Networking** (from foundation/network module):

   - VPC with private and public subnets
   - Internet Gateway and NAT Gateways
   - Route tables configured

2. **SSM Parameters** (created by foundation/network module):
   - `/${APP}/${ENV}/vpc-id` - VPC ID
   - `/${APP}/${ENV}/vpc-private-subnet-ids` - Private subnet IDs (comma-separated)
   - `/${APP}/${ENV}/vpc-public-subnet-ids` - Public subnet IDs (comma-separated)

## Configuration

### Key Variables

| Variable | Description                                           | Type   | Required | Default |
| -------- | ----------------------------------------------------- | ------ | -------- | ------- |
| APP      | Application name used for resource naming and tagging | string | Yes      | -       |
| ENV      | Environment name (e.g., dev, test, prod)              | string | Yes      | -       |
| REGION   | AWS region for resource deployment                    | string | Yes      | -       |

### Terraform Variables File

The module uses `terraform.tfvars` with placeholder values that are replaced during deployment:

```hcl
APP    = "APP_NAME"
ENV    = "ENV_NAME"
REGION = "AWS_PRIMARY_REGION"
```

These placeholders are automatically replaced by the deployment scripts with actual values.

## Deployment

### Using Makefile

```bash
# Deploy MSK data source module
make deploy-msk-source

# Destroy MSK data source module
make destroy-msk-source
```

### Direct Terraform

```bash
cd iac/roots/datasources/msk

# Initialize (backend config is embedded in backend.tf)
terraform init

# Plan
terraform plan -var-file=terraform.tfvars

# Apply
terraform apply -var-file=terraform.tfvars
```

## Backend Configuration

This module uses Terraform S3 backend with the following configuration:

- **S3 Bucket**: `${TF_S3_BACKEND_NAME}-${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}`
- **State Key**: `${ENV_NAME}/datasources/msk/terraform.tfstate`
- **DynamoDB Table**: `${TF_S3_BACKEND_NAME}-lock`
- **Encryption**: Enabled

## Integration with Other Components

### Data Producers

- **Data Generator Lambda Functions**: Publish streaming events to MSK topics
- **External Applications**: Can publish data via Kafka producers
- **Scheduled Jobs**: Generate periodic data for testing and simulation

### Data Consumers

- **AWS Glue Streaming**: Processes streaming data from MSK topics
- **Amazon Data Firehose**: Consumes data from MSK for delivery to S3
- **Custom Applications**: Can consume data via Kafka consumers

### Downstream Processing

- **S3 Iceberg Storage**: Final destination for processed streaming data
- **AWS Glue Data Catalog**: Metadata management for streaming datasets
- **Query Engines**: Athena and Snowflake for analytics

## Security

### Network Security

- MSK cluster deployed in private subnets only
- Security groups restrict access to VPC CIDR and authorized applications
- No public internet access to MSK cluster
- Management EC2 instance in public subnet for administrative access

### Access Control

- **SASL/IAM Authentication**: Integrated with AWS IAM for access control
- **Security Group Rules**: Network-level access control
- **VPC Isolation**: Network-level security through VPC boundaries

### IAM Permissions

The management EC2 instance has comprehensive MSK permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["kafka:ListClustersV2", "kafka:GetBootstrapBrokers"],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "kafka-cluster:Connect",
        "kafka-cluster:DescribeCluster",
        "kafka:DescribeCluster",
        "kafka:DescribeClusterV2",
        "kafka-cluster:AlterCluster",
        "kafka-cluster:*Topic*",
        "kafka-cluster:WriteData",
        "kafka-cluster:ReadData"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:kafka:region:account:cluster/cluster-name/*",
        "arn:aws:kafka:region:account:topic/cluster-name/*"
      ]
    }
  ]
}
```

## Management EC2 Instance

### Purpose

The management EC2 instance provides:

- **Topic Management**: Create, modify, and delete Kafka topics
- **Cluster Monitoring**: Monitor cluster health and performance
- **Configuration Management**: Adjust cluster and topic configurations
- **Troubleshooting**: Debug connectivity and performance issues

### User Data Script

The EC2 instance is configured with a user data script that:

- Installs Kafka client tools
- Configures AWS CLI and credentials
- Sets up environment variables for cluster access
- Creates helper scripts for common operations

### Accessing the Management Instance

**Prerequisites**: Install AWS CLI Session Manager plugin:
- **Installation Guide**: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
- **Required for**: `make connect-to-msk-config` command

**Connection Methods**:
```bash
# Using Makefile command (recommended)
make connect-to-msk-config

# Connect via SSM Session Manager (recommended)
aws ssm start-session --target <instance-id>

# Or via SSH if configured
ssh -i your-key.pem ec2-user@<public-ip>
```

### Common Management Tasks

```bash
# List topics
kafka-topics.sh --bootstrap-server <bootstrap-servers> \
  --command-config client.properties --list

# Create a topic
kafka-topics.sh --bootstrap-server <bootstrap-servers> \
  --command-config client.properties --create \
  --topic trading-data-topic --partitions 3 --replication-factor 2

# Describe a topic
kafka-topics.sh --bootstrap-server <bootstrap-servers> \
  --command-config client.properties --describe \
  --topic trading-data-topic

# Check consumer group status
kafka-consumer-groups.sh --bootstrap-server <bootstrap-servers> \
  --command-config client.properties --describe \
  --group my-consumer-group
```

## Monitoring

### CloudWatch Metrics

MSK automatically publishes metrics to CloudWatch:

- **Cluster Metrics**: CPU utilization, memory usage, network I/O
- **Topic Metrics**: Message throughput, partition count, bytes in/out
- **Consumer Metrics**: Lag, consumption rate, active consumers

### Recommended Alarms

```hcl
# High consumer lag alarm
resource "aws_cloudwatch_metric_alarm" "high_consumer_lag" {
  alarm_name          = "${var.APP}-${var.ENV}-msk-high-consumer-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "EstimatedMaxTimeLag"
  namespace           = "AWS/MSK"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "60000" # 1 minute in milliseconds
  alarm_description   = "This metric monitors MSK consumer lag"

  dimensions = {
    "Cluster Name" = module.msk_cluster.name
  }
}

# High throughput alarm
resource "aws_cloudwatch_metric_alarm" "high_throughput" {
  alarm_name          = "${var.APP}-${var.ENV}-msk-high-throughput"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BytesInPerSec"
  namespace           = "AWS/MSK"
  period              = "300"
  statistic           = "Average"
  threshold           = "1000000" # 1MB/sec
  alarm_description   = "This metric monitors MSK throughput"

  dimensions = {
    "Cluster Name" = module.msk_cluster.name
  }
}
```

## Troubleshooting

### Common Issues

1. **MSK Cluster Creation Fails**

   - Verify VPC and subnet configuration
   - Check security group rules
   - Ensure sufficient IP addresses in subnets
   - Validate IAM permissions for MSK service

2. **Connection Issues from Applications**

   - Verify security group rules allow traffic on port 9098
   - Check that applications are in the correct subnets
   - Validate MSK cluster endpoint configuration
   - Ensure SASL/IAM authentication is properly configured

3. **Performance Issues**

   - Monitor CloudWatch metrics for resource utilization
   - Check topic partition configuration
   - Review consumer group settings and lag
   - Optimize producer and consumer configurations

4. **Authentication Failures**
   - Verify IAM roles have required kafka-cluster permissions
   - Check that SASL/IAM is properly configured in client applications
   - Ensure AWS credentials are available to client applications

### Diagnostic Commands

```bash
# Check cluster status
aws kafka describe-cluster --cluster-arn <cluster-arn>

# List all clusters
aws kafka list-clusters

# Get bootstrap brokers
aws kafka get-bootstrap-brokers --cluster-arn <cluster-arn>

# Test connectivity
telnet <bootstrap-server> 9098

# Check security group rules
aws ec2 describe-security-groups --group-ids <security-group-id>

# View CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/msk"
```

## Cost Optimization

### Cost Monitoring

- Use AWS Cost Explorer to track MSK costs
- Set up billing alerts for unexpected cost increases
- Monitor CloudWatch metrics to understand usage patterns
- Optimize topic retention policies to reduce storage costs

### Best Practices

- Configure appropriate retention policies for topics
- Use compression in producers to reduce network costs
- Monitor and optimize partition counts
- Use batch processing where appropriate to reduce API calls

## Dependencies

This module depends on:

1. **Foundation Network Module**: Provides VPC, subnets, and networking configuration
2. **MSK Provisioned Module Template**: Reusable module for MSK cluster creation
3. **EC2 Module Template**: Reusable module for management EC2 instance

## Module Structure

```
iac/roots/datasources/msk/
├── README.md              # This documentation
├── backend.tf             # Terraform S3 backend configuration
├── cluster.tf             # MSK cluster resource using module template
├── ec2.tf                 # Management EC2 instance and IAM configuration
├── ec2-user-data.sh       # EC2 initialization script
├── lookups.tf             # Data sources for VPC and subnet information
├── provider.tf            # AWS provider configuration
├── sg.tf                  # Security group definitions
├── terraform.tfvars       # Variable values with placeholders
└── variables.tf           # Input variable declarations
```

## Outputs

The module provides outputs for integration with other components:

- **MSK Cluster ARN**: For referencing the cluster in other modules
- **Bootstrap Servers**: For client application configuration
- **Security Group IDs**: For configuring access from other resources

## Tags

All resources are tagged with:

- `Application` - Application name from APP variable
- `Environment` - Environment name from ENV variable

Additional resource-specific tags are applied as appropriate.

## Integration Examples

### Lambda Function Producer

```python
import json
import boto3
from kafka import KafkaProducer

def lambda_handler(event, context):
    # Configure producer with SASL/IAM
    producer = KafkaProducer(
        bootstrap_servers=['<bootstrap-servers>'],
        security_protocol='SASL_SSL',
        sasl_mechanism='AWS_MSK_IAM',
        sasl_oauth_token_provider=lambda: get_aws_token(),
        value_serializer=lambda v: json.dumps(v).encode('utf-8')
    )

    # Send message
    producer.send('trading-data-topic', {
        'timestamp': event['timestamp'],
        'data': event['data']
    })

    producer.flush()
    producer.close()

    return {'statusCode': 200}

def get_aws_token():
    # Implementation for AWS IAM token
    pass
```

### Glue Streaming Job Consumer

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *

spark = SparkSession.builder.appName("MSKStreaming").getOrCreate()

# Read from MSK
df = spark \
    .readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "<bootstrap-servers>") \
    .option("kafka.security.protocol", "SASL_SSL") \
    .option("kafka.sasl.mechanism", "AWS_MSK_IAM") \
    .option("subscribe", "trading-data-topic") \
    .load()

# Process the stream
processed_df = df.select(
    col("key").cast("string"),
    col("value").cast("string"),
    col("timestamp")
)

# Write to S3 in Iceberg format
query = processed_df.writeStream \
    .format("iceberg") \
    .outputMode("append") \
    .option("path", "s3://my-bucket/iceberg-table/") \
    .option("checkpointLocation", "s3://my-bucket/checkpoints/") \
    .start()

query.awaitTermination()
```

## References

- [Amazon MSK Developer Guide](https://docs.aws.amazon.com/msk/latest/developerguide/)
- [MSK Provisioned Documentation](https://docs.aws.amazon.com/msk/latest/developerguide/msk-provision.html)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [AWS MSK Best Practices](https://docs.aws.amazon.com/msk/latest/developerguide/bestpractices.html)
- [MSK SASL/IAM Authentication](https://docs.aws.amazon.com/msk/latest/developerguide/iam-access-control.html)
