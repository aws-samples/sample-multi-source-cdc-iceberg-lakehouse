# Data Sources Infrastructure Layer

## Overview

The data sources layer provides the infrastructure components for various data sources used in the Iceberg Data Lakehouse project. This layer creates the necessary AWS resources to host and configure different database systems, streaming platforms, and data generation services that serve as data sources for the data lakehouse.

## Architecture Components

The data sources layer consists of 5 core modules that provide diverse data sources for testing different ingestion patterns:

### 1. Oracle Database Module
**Purpose**: Oracle Database 21c Express Edition on EC2 for transactional data source

**Key Resources:**
- **Oracle 21c XE on EC2**: r5.2xlarge instance with 100GB encrypted EBS volume
- **Database Configuration**: XE SID with XEPDB1 pluggable database
- **Security Group**: Oracle (1521) and SSH (22) access from VPC
- **Secrets Management**: Auto-generated passwords in Secrets Manager
- **SSM Parameters**: Connection strings and database configuration
- **IAM Role**: EC2 role with Secrets Manager and SSM access

**Use Cases:**
- Source system simulation for CDC testing
- DMS integration as primary replication source
- Oracle-specific data type validation
- Synthetic trading data generation target

### 2. Aurora PostgreSQL Module
**Purpose**: Aurora PostgreSQL cluster for high-performance transactional workloads

**Key Resources:**
- **Aurora PostgreSQL 16.4 Cluster**: Multi-AZ cluster with 2 instances
- **Database**: `equitydb` with master user credentials in Secrets Manager
- **Security Group**: PostgreSQL access from private subnets
- **Optional Bastion Host**: EC2 instance for secure database access via SSM
- **Enhanced Monitoring**: 5-minute intervals with performance insights

**Use Cases:**
- Source system simulation for financial systems
- DMS replication source for continuous data changes
- Performance testing with concurrent operations

### 3. CockroachDB Module
**Purpose**: Distributed SQL database for horizontal scalability testing

**Key Resources:**
- **CockroachDB Cluster**: Multi-node insecure deployment on EC2
- **Load Balancer**: Network Load Balancer for traffic distribution
- **Security Groups**: Inter-node communication and client access
- **Management Tools**: Kafka client tools and monitoring capabilities
- **Clock Synchronization**: Amazon Time Sync Service integration

**Use Cases:**
- Distributed database CDC testing
- Horizontal scalability validation
- Multi-region data replication
- Changefeed-based streaming integration

### 4. MSK (Managed Streaming for Kafka) Module
**Purpose**: Serverless Kafka cluster for streaming data sources

**Key Resources:**
- **Serverless MSK Cluster**: Auto-scaling Kafka cluster
- **Security Groups**: MSK cluster and EC2 management clients
- **Management EC2**: Kafka topic management and monitoring
- **SASL/IAM Authentication**: AWS service integration
- **Multi-AZ Deployment**: High availability across zones

**Use Cases:**
- Primary streaming data source
- Lambda function data publishing
- Real-time event processing
- Streaming analytics integration

### 5. Data Generator Module
**Purpose**: EC2-based synthetic data generation for all data sources

**Key Resources:**
- **EC2 Instance**: Comprehensive transaction data generator
- **Multi-format Support**: Financial and brokerage transaction data (~200 columns each)
- **Database Integration**: PostgreSQL, Oracle, MySQL, SQL Server support
- **MSK Publishing**: Kafka producer capabilities
- **Flexible Configuration**: Command-line options for various scenarios

**Use Cases:**
- Synthetic data generation for testing
- Database population for CDC sources
- MSK topic publishing for streaming tests
- Multi-threading for high-volume data generation

## Deployment Architecture

### Deployment Order
Data sources must be deployed after the foundation layer:

```bash
# 1. Foundation Layer (required first)
make deploy-foundation

# 2. Data Sources Layer (takes ~1hr 40min for MSK)
make deploy-datasources
```

**Individual module deployment:**
```bash
make deploy-oracle      # Oracle Database 21c XE
make deploy-aurora      # Aurora PostgreSQL cluster
make deploy-cockroach   # CockroachDB distributed cluster
make deploy-msk         # MSK provisioned cluster
make deploy-data-generator  # Data generation EC2 instance
```

### Connection Requirements
All data source modules require AWS Session Manager Plugin for secure connections:

**Installation**: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

**Connection Commands:**
```bash
make connect-to-oracle          # Oracle database access
make connect-to-aurora          # Aurora bastion host (if enabled)
make connect-to-msk-config      # MSK management instance
make connect-to-data-generator  # Data generator instance
```

## Integration Patterns

### CDC (Change Data Capture) Sources
**Oracle, Aurora, CockroachDB** → DMS/Changefeed → MSK → Firehose → Lambda Transformation → S3 Iceberg

- **Oracle**: DMS CDC captures database changes
- **Aurora**: DMS replication with PostgreSQL compatibility
- **CockroachDB**: Native changefeed streaming (requires manual enablement)

### Direct Streaming Sources
**Data Generator** → MSK → Firehose → S3 Iceberg (no transformation)

- Lambda-generated synthetic data
- Pre-formatted transaction records
- Direct MSK publishing without CDC overhead

## Data Generation Capabilities

### Transaction Types
- **Financial Transactions**: ~200 columns including customer demographics, merchant info, payment methods, risk indicators
- **Brokerage Transactions**: ~200 columns including order management, security details, execution data, compliance fields

### Generation Modes
- **Console Output**: JSON formatted transaction data
- **Database Mode**: Direct insertion into relational databases
- **MSK Publishing**: Kafka producer for streaming scenarios
- **Continuous Generation**: Long-running data streams for testing

### Configuration Options
```bash
# Generate financial transactions to Oracle
./oracle/run-oracle-financial.sh 1000

# Generate brokerage data to Aurora
./aurora/run-aurora-brokerage.sh 500

# Stream both types to MSK
./msk/run-msk-both.sh 2000

# CockroachDB changefeed (requires manual setup)
./cockroach/run-cockroach-financial.sh 1000
```

## Security Features

### Network Security
- All databases deployed in private subnets
- Security groups restrict access to VPC CIDR
- No public internet access to database instances
- Management instances in public subnets for administrative access

### Encryption & Access Control
- KMS encryption for EBS volumes and database storage
- Auto-generated secure passwords in Secrets Manager
- IAM roles following principle of least privilege
- SSM Session Manager for secure shell access

### Authentication Methods
- **Oracle**: SYS/SYSTEM admin users + application user
- **Aurora**: Master user with IAM database authentication
- **CockroachDB**: Insecure mode for testing (development only)
- **MSK**: SASL/IAM authentication for AWS service integration

## Monitoring & Operations

### CloudWatch Integration
- Database performance metrics and logs
- MSK cluster metrics (throughput, lag, errors)
- EC2 instance monitoring for data generators
- Custom dashboards for operational visibility

### Management Capabilities
- **Oracle**: SQL*Plus access via SSM
- **Aurora**: PostgreSQL client tools on bastion host
- **CockroachDB**: DB Console at port 8080
- **MSK**: Kafka client tools on management instance
- **Data Generator**: Real-time generation monitoring

## Cost Optimization

### Resource Sizing
- **Oracle**: r5.2xlarge with 100GB storage (adjustable)
- **Aurora**: Multi-AZ with 2 instances (production-ready)
- **CockroachDB**: Multi-node for fault tolerance
- **MSK**: Provisioned cluster with IAM authentication
- **Data Generator**: Optimized for synthetic data generation

### Operational Efficiency
- Aurora Multi-AZ with 2 instances for high availability
- Cost allocation tags for resource tracking

## Dependencies

### Foundation Layer Requirements
- VPC with public and private subnets
- KMS keys for encryption
- IAM roles and policies
- S3 buckets for assets and logs
- SSM parameters for cross-module reference

### Cross-Module Integration
- Data generator integrates with all database modules
- MSK cluster receives data from multiple sources
- Secrets Manager provides secure credential storage
- CloudWatch provides unified monitoring

## Outputs & Integration

Each module provides outputs for integration with the ingestion layer:
- **Database Connection Details**: Host, port, credentials
- **MSK Cluster Information**: Bootstrap servers, security groups
- **Instance IDs**: For management and monitoring
- **Security Group References**: For ingestion layer access

For detailed module-specific documentation, see individual README files in each subdirectory.
