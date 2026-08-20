# Data Generator Module

This Terraform module deploys an EC2 instance that runs a comprehensive transaction data generator. The instance generates synthetic financial and brokerage transaction data and streams it to various destinations including Amazon MSK (Kafka) and relational databases.

## Features

- **Rich Transaction Data**: Generates realistic financial transaction data with **101 columns** and brokerage transaction data with **180 columns**
- **Multiple Destinations**: Supports publishing to Amazon MSK (Kafka) and writing to relational databases (PostgreSQL, Oracle, CockroachDB)
- **Flexible Transaction Types**: Generate financial, brokerage, or both transaction types simultaneously
- **Configurable Parameters**: Extensive customization options for data generation patterns and volumes
- **Multi-threading Support**: High-volume data generation with parallel processing capabilities
- **Clean Architecture**: Extensible design with minimal code duplication using inheritance patterns
- **Automated Deployment**: Complete EC2 setup with Java application, Kafka tools, and data generation scripts
- **Conditional Configuration**: Only deploys components for enabled data sources (MSK, Oracle, Aurora, CockroachDB)

## Architecture

The data generator is built with a modular, object-oriented architecture that supports multiple transaction types through a common base class system:

### Core Components

- **`BaseTransactionGenerator`**: Abstract base class containing shared functionality across all transaction types
  - Customer demographics and financial profiles
  - Location and IP geolocation data generation
  - Risk and fraud indicator calculations
  - Common utility methods (timestamps, income calculation, IP addresses)

- **`FinancialTransactionGenerator`**: Extends BaseTransactionGenerator for financial transaction data
  - Generates **101 columns** of comprehensive financial transaction data
  - Includes payment methods, merchant information, transaction categories
  - Handles transaction amounts, currencies, and exchange rates

- **`BrokerageTransactionGenerator`**: Extends BaseTransactionGenerator for brokerage trading data
  - Generates **180 columns** of detailed brokerage transaction data
  - Covers order management, security details, execution information
  - Includes market data, risk metrics, and performance analytics

- **`DatabaseTransactionWriter`**: Generic database writer supporting both transaction types
  - Automatic table creation with appropriate schemas
  - Support for PostgreSQL, Oracle, and CockroachDB
  - Dynamic column mapping and data type conversion

- **`GenericDataGeneratorThread`**: Thread implementation working with any transaction generator
  - Supports both fixed record count and continuous generation modes
  - Configurable intervals and duration settings
  - Graceful shutdown handling

- **`EC2DataGeneratorApplication`**: Main application with comprehensive command-line interface
  - Multi-destination support (console, MSK, database)
  - Parallel processing for multiple transaction types
  - Extensive configuration options and validation

### Shared Functionality

The BaseTransactionGenerator provides common methods used across all transaction types:
- **Customer Information**: Demographics, income profiles, risk categories, loyalty tiers
- **Location Data**: IP geolocation, geographic anomaly detection, VPN/proxy usage
- **Risk Indicators**: Fraud scores, behavioral patterns, velocity checks
- **Utility Methods**: Timestamp generation, income calculation, data formatting

## Transaction Types & Schema Details

### Financial Transactions (101 Columns)

Generates comprehensive financial transaction data including:

#### Core Transaction Details (15 columns)
- Transaction identifiers (ID, reference ID, type, subtype)
- Timestamps (ISO 8601, date, time, timezone)
- Amounts (transaction, original, currency, exchange rate)
- Status and description information

#### Customer Demographics (20 columns)
- Personal information (age, gender, income, marital status)
- Geographic data (country, state, city, zip code)
- Financial profile (income range, employment, education)
- Account details (KYC status, VIP flag, loyalty tier, tenure)

#### Merchant Information (12 columns)
- Merchant identifiers and business details
- Category codes and classifications
- Geographic location and ratings
- Risk indicators (chargeback rate, high-risk flag)

#### Payment Method Details (10 columns)
- Payment types (credit card, debit card, digital wallet)
- Card information (last four digits, expiry, issuer)
- Funding types and card levels
- Bank identification numbers (BIN)

#### Location & IP Data (10 columns)
- IP address and geolocation coordinates
- Geographic anomaly detection
- VPN, proxy, and Tor usage flags
- Cross-border transaction indicators

#### Risk & Fraud Analysis (20 columns)
- Fraud detection scores and types
- Behavioral and velocity risk scores
- Account takeover risk assessment
- Historical fraud and chargeback flags

#### Transaction History & Analytics (14 columns)
- Historical transaction counts (7d, 30d, 90d, 365d)
- Transaction amounts and averages
- Online transaction ratios
- Activity patterns and metrics

**📁 Schema Reference**: See [`schemas/financial-transaction-schema.json`](schemas/financial-transaction-schema.json) for complete field definitions, data types, and validation rules.

### Brokerage Transactions (180 Columns)

Generates realistic brokerage trading data including:

#### Order Management (25 columns)
- Order identifiers (Order ID, Client Order ID, Parent Order ID)
- Order types (MARKET, LIMIT, STOP, STOP_LIMIT, TRAILING_STOP, BRACKET, OCO, ICEBERG)
- Order sides (BUY, SELL, BUY_TO_COVER, SELL_SHORT)
- Order status (NEW, PARTIALLY_FILLED, FILLED, CANCELLED, REJECTED, EXPIRED)
- Time in force (DAY, GTC, IOC, FOK, GTD, ATC, ATO)
- Quantities (order, filled, remaining, minimum, disclosed)

#### Security Details (20 columns)
- Security identifiers (Symbol, CUSIP, ISIN, SEDOL)
- Security types (STOCK, ETF, OPTION, BOND, MUTUAL_FUND, FUTURES, FOREX, CRYPTO)
- Exchange information (NYSE, NASDAQ, AMEX, BATS, IEX)
- Sector, industry, and market cap categories
- Option-specific fields (strike price, expiration, underlying symbol)

#### Account & Customer Information (25 columns)
- Account types (INDIVIDUAL, JOINT, IRA, ROTH_IRA, 401K, TRUST, CORPORATE, MARGIN, CASH)
- Account balances (equity, buying power, margin balance, day trading buying power)
- Pattern day trader flags and account status
- Customer demographics (inherited from BaseTransactionGenerator)
- Risk categories and compliance flags

#### Execution & Pricing (30 columns)
- Price levels (market, limit, stop, average fill, last fill)
- Market data (bid/ask prices and sizes, volume, VWAP)
- Execution details (venue, routing, liquidity indicators)
- Fill information (quantities, values, execution IDs)
- Commission and fee structures

#### Risk & Compliance (25 columns)
- Pre/post-trade risk checks and position limits
- Regulatory transaction IDs and CAT reporter IDs
- Wash sale flags and short sale exempt indicators
- Large trader, institutional account, and employee flags
- Market maker, proprietary trading, and algorithmic flags

#### Performance Analytics (35 columns)
- Order latency and fill rates
- Slippage and implementation shortfall
- Market impact and timing costs
- Participation rates and order aggressiveness
- Historical metrics (7d, 30d order counts and volumes)
- Success rates and average order sizes

#### Market Data & Conditions (20 columns)
- Real-time pricing (open, high, low, close, previous close)
- Volume and volatility indicators
- Market conditions and benchmark pricing
- Beta calculations and correlation metrics

**📁 Schema Reference**: See [`schemas/brokerage-transaction-schema.json`](schemas/brokerage-transaction-schema.json) for complete field definitions, data types, and validation rules.

## Database Integration

The module supports integration with multiple relational databases deployed separately. When enabled, the data generator will:

1. **Connect Securely**: Uses AWS Secrets Manager for database credentials
2. **Auto-Create Tables**: Dynamically creates appropriate table schemas based on transaction type
3. **Generate & Insert**: Produces synthetic transaction data and inserts into database tables
4. **Handle Multiple Types**: Supports both financial and brokerage transactions with separate tables

### Supported Databases

- **PostgreSQL/Aurora PostgreSQL**: Full support with PostgreSQL-specific data types and syntax
- **Oracle Database**: Complete Oracle support with Oracle-specific SQL syntax and data types
- **CockroachDB**: Full compatibility with CockroachDB-specific features and syntax

### Database Integration Variables

Configure database integration through Terraform variables:

```hcl
# Oracle Database Integration
ENABLE_ORACLE_INTEGRATION = true
ORACLE_FINANCIAL_TRANSACTIONS_TABLE_NAME = "oracle_financial_transactions"
ORACLE_BROKERAGE_TRANSACTIONS_TABLE_NAME = "oracle_brokerage_transactions"

# Aurora PostgreSQL Integration  
ENABLE_AURORA_INTEGRATION = true
AURORA_FINANCIAL_TRANSACTIONS_TABLE_NAME = "aurora_financial_transactions"
AURORA_BROKERAGE_TRANSACTIONS_TABLE_NAME = "aurora_brokerage_transactions"

# CockroachDB Integration
ENABLE_COCKROACH_INTEGRATION = true
```

### Prerequisites for Database Integration

1. **Database Module Deployment**: The target database module must be deployed first
2. **Network Connectivity**: Database instance must be accessible from the data generator's VPC/subnet
3. **Secrets Manager**: Database connection secret must exist with the expected JSON format
4. **Permissions**: Data generator IAM role must have access to read the database secret

### Database Secret Format

Each database module creates a secret in AWS Secrets Manager with this JSON structure:

```json
{
  "username": "trading_user",
  "password": "generated_password",   # pragma: allowlist secret
  "host": "database_private_ip",
  "port": "5432",
  "dbname": "trading_db",
  "engine": "postgresql"
}
```

**Engine Types**:
- `"postgresql"` for Aurora PostgreSQL
- `"oracle"` for Oracle Database  
- `"cockroachdb"` for CockroachDB

### Automatic Table Creation

The system automatically creates appropriate table schemas:

- **Financial Transactions**: Tables with **101 columns** optimized for financial data
- **Brokerage Transactions**: Tables with **180 columns** optimized for trading data
- **Database-Specific**: Uses appropriate data types and constraints for each database engine
- **Dynamic Schema**: Tables created based on actual transaction fields generated

### Table Naming Conventions

Tables are created with consistent naming patterns:
- `{source}_financial_transactions` (e.g., `oracle_financial_transactions`)
- `{source}_brokerage_transactions` (e.g., `aurora_brokerage_transactions`)

## Usage

### Terraform Configuration

#### Basic Usage (MSK only)

```hcl
module "data_generator" {
  source = "./data-generator"

  APP    = "${APP_NAME}"
  ENV    = "${ENV_NAME}"
  REGION = "us-east-1"
}
```

#### Multi-Database Integration

```hcl
module "data_generator" {
  source = "./data-generator"

  APP    = "${APP_NAME}"
  ENV    = "${ENV_NAME}"
  REGION = "us-east-1"

  # Enable multiple data sources
  ENABLE_MSK_INTEGRATION        = true
  ENABLE_ORACLE_INTEGRATION     = true
  ENABLE_AURORA_INTEGRATION     = true
  ENABLE_COCKROACH_INTEGRATION  = true

  # Table name customization
  ORACLE_FINANCIAL_TRANSACTIONS_TABLE_NAME   = "oracle_financial_transactions"
  ORACLE_BROKERAGE_TRANSACTIONS_TABLE_NAME   = "oracle_brokerage_transactions"
  AURORA_FINANCIAL_TRANSACTIONS_TABLE_NAME   = "aurora_financial_transactions"
  AURORA_BROKERAGE_TRANSACTIONS_TABLE_NAME   = "aurora_brokerage_transactions"
}
```

### Command Line Usage

The Java data generator supports extensive command-line options for flexible data generation:

#### General Options
```bash
--num-records <n>             Number of records to generate (default: 5)
--interval <n>                Interval between messages in ms (default: 1000)
--continuous                  Run continuously
--duration <n>                Duration in seconds for continuous mode (default: 60)
--region <s>                  AWS region (default: us-east-1)
--transaction-type <s>        Transaction type: 'financial', 'brokerage', or 'both' (default: financial)
--help                        Print help message
```

#### Console Output Options
```bash
--pretty-print                Pretty print JSON output (default: true)
--no-pretty-print             Disable pretty printing of JSON output
```

#### MSK Publishing Options
```bash
--enable-msk                  Enable publishing to MSK
--bootstrap-servers-secret <s> Secret name containing MSK bootstrap servers
--topic <s>                   MSK topic name
```

#### Database Options
```bash
--enable-database             Enable writing to database
--db-secret <s>               Secret name containing database connection details
--table-name <s>              Table name (auto-determined by transaction type if not specified)
--no-create-table             Don't create the table if it doesn't exist
```

### Usage Examples

#### Console Output Mode
```bash
# Generate 10 financial transactions with pretty printing
java -jar generator.jar --num-records 10 --transaction-type financial --pretty-print

# Generate 5 brokerage transactions without pretty printing
java -jar generator.jar --num-records 5 --transaction-type brokerage --no-pretty-print

# Generate both types (5 of each)
java -jar generator.jar --num-records 10 --transaction-type both
```

#### Database Mode
```bash
# Financial transactions to Oracle
java -jar generator.jar \
  --enable-database \
  --db-secret "oracle-secret" \
  --transaction-type financial \
  --table-name "oracle_financial_transactions" \
  --num-records 1000

# Brokerage transactions to Aurora PostgreSQL
java -jar generator.jar \
  --enable-database \
  --db-secret "aurora-secret" \
  --transaction-type brokerage \
  --table-name "aurora_brokerage_transactions" \
  --num-records 500

# Both types to CockroachDB (auto table names)
java -jar generator.jar \
  --enable-database \
  --db-secret "cockroach-secret" \
  --transaction-type both \
  --num-records 2000
```

#### MSK Publishing Mode
```bash
# Continuous financial transactions to MSK
java -jar generator.jar \
  --enable-msk \
  --bootstrap-servers-secret "msk-secret" \
  --topic "financial-transactions" \
  --transaction-type financial \
  --continuous \
  --duration 3600 \
  --interval 500

# Both types to separate MSK topics
java -jar generator.jar \
  --enable-msk \
  --bootstrap-servers-secret "msk-secret" \
  --topic "all-transactions" \
  --transaction-type both \
  --num-records 5000 \
  --interval 100
```

#### Combined Mode (Database + MSK)
```bash
# Publish to both database and MSK simultaneously
java -jar generator.jar \
  --enable-database \
  --db-secret "aurora-secret" \
  --enable-msk \
  --bootstrap-servers-secret "msk-secret" \
  --topic "financial-stream" \
  --transaction-type financial \
  --continuous \
  --duration 1800
```

## Connection Information

**Prerequisites**: Install AWS CLI Session Manager plugin:
- **Installation Guide**: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
- **Required for**: `make connect-to-data-generator` command

**Connection Methods**:
```bash
# Using Makefile command (recommended)
make connect-to-data-generator

# Direct AWS CLI command
aws ssm start-session --target <instance-id> --region <region>
```

## Data Generation Process

The data generator runs automatically when the EC2 instance starts up. The complete process includes:

### 1. Environment Setup
- **Java Installation**: Amazon Corretto 21 JDK for optimal performance
- **Maven Build**: Compiles the Java application from source code
- **Kafka Tools**: Downloads and configures Kafka client tools (if MSK enabled)
- **Environment Variables**: Sets up all configuration parameters for data sources

### 2. Conditional Component Installation
Based on enabled services in `terraform.tfvars`:
- **MSK Components**: Kafka client, topic creation, IAM authentication setup
- **Database Drivers**: PostgreSQL, Oracle, CockroachDB JDBC drivers
- **Security Configuration**: AWS Secrets Manager integration for credentials

### 3. Topic and Table Management
- **MSK Topics**: Automatically creates required Kafka topics with proper partitioning
- **Database Tables**: Dynamically creates tables with appropriate schemas
- **Schema Validation**: Ensures compatibility between generated data and target schemas

### 4. Script Generation
Creates data generation scripts based on enabled services:
- **MSK Scripts**: `./msk/run-msk-financial.sh`, `./msk/run-msk-brokerage.sh`, `./msk/run-msk-both.sh`
- **Oracle Scripts**: `./oracle/run-oracle-financial.sh`, `./oracle/run-oracle-brokerage.sh`, `./oracle/run-oracle-both.sh`
- **Aurora Scripts**: `./aurora/run-aurora-financial.sh`, `./aurora/run-aurora-brokerage.sh`, `./aurora/run-aurora-both.sh`
- **CockroachDB Scripts**: `./cockroach/run-cockroach-financial.sh`, `./cockroach/run-cockroach-brokerage.sh`, `./cockroach/run-cockroach-both.sh`

### 5. Data Generation Execution
- **Multi-threaded Processing**: Parallel generation for high-volume scenarios
- **Real-time Streaming**: Continuous data generation with configurable intervals
- **Error Handling**: Robust error recovery and logging mechanisms
- **Performance Monitoring**: Built-in metrics and performance tracking

## How Data Generation Works

### Transaction Generation Algorithm

#### 1. Base Data Population (Shared across both types)
```java
// Customer demographics with realistic distributions
int age = 18 + random.nextInt(68);
int income = generateIncomeBasedOnAge(age);
String riskCategory = determineRiskCategory(income, age);

// Geographic data with IP geolocation
String ipAddress = generateRealisticIpAddress();
Location geoLocation = generateGeolocationFromIp(ipAddress);

// Risk and fraud indicators with correlated patterns
boolean isFraud = random.nextDouble() < 0.02; // 2% fraud rate
double fraudScore = isFraud ? 70.0 + random.nextDouble() * 30.0 : random.nextDouble() * 50.0;
```

#### 2. Financial Transaction Specifics (101 columns)
```java
// Transaction core data
String transactionId = "TXN" + generateUuid().substring(0, 12);
double amount = generateRealisticAmount(customerIncome, transactionCategory);
String merchantCategory = selectWeightedMerchantCategory();

// Payment method correlation
PaymentMethod paymentMethod = selectPaymentMethodBasedOnAmount(amount);
String cardBin = generateBinBasedOnPaymentMethod(paymentMethod);

// Historical patterns
TransactionHistory history = generateHistoricalPatterns(customerId);
```

#### 3. Brokerage Transaction Specifics (180 columns)
```java
// Order management
String orderId = "ORD" + System.currentTimeMillis() + random.nextInt(1000);
OrderType orderType = selectOrderTypeBasedOnMarketConditions();
SecurityType securityType = selectWeightedSecurityType();

// Market data correlation
double bidPrice = generateRealisticBidPrice(symbol);
double askPrice = bidPrice + generateRealisticSpread(securityType);
int volume = generateVolumeBasedOnMarketCap(symbol);

// Performance analytics
double slippage = calculateSlippage(orderType, marketConditions);
double implementationShortfall = calculateImplementationShortfall(orderPrice, benchmarkPrice);
```

### Data Realism Features

#### 1. Correlated Data Generation
- **Income-Age Correlation**: Higher incomes for middle-aged customers
- **Risk-Amount Correlation**: Higher amounts trigger higher risk scores
- **Geographic Consistency**: IP geolocation matches customer residence
- **Market Data Correlation**: Bid/ask spreads realistic for security types

#### 2. Realistic Distributions
- **Transaction Amounts**: Log-normal distribution with category-specific parameters
- **Time Patterns**: Business hours weighting for financial transactions
- **Market Hours**: Trading hours consideration for brokerage transactions
- **Seasonal Patterns**: Holiday and weekend adjustments

#### 3. Business Logic Implementation
- **Fraud Detection**: Realistic fraud patterns with velocity checks
- **Market Conditions**: Order types influenced by market volatility
- **Account Balances**: Buying power calculations for brokerage accounts
- **Risk Management**: Pre-trade risk checks and position limits

### Customization and Tweaking

#### 1. Volume and Performance Tuning
```bash
# High-volume generation (10,000 records with minimal interval)
./msk/run-msk-financial.sh 10000
# Interval controlled in Java application: --interval 50

# Continuous streaming (1 hour duration)
java -jar generator.jar --continuous --duration 3600 --interval 1000

# Batch processing (large volumes with database optimization)
java -jar generator.jar --enable-database --num-records 100000 --interval 0
```

#### 2. Data Distribution Customization
Modify the Java source code to adjust:
- **Fraud Rate**: Change `random.nextDouble() < 0.02` to desired percentage
- **Income Distribution**: Adjust `generateIncomeBasedOnAge()` method parameters
- **Transaction Categories**: Modify category weights in transaction generators
- **Geographic Distribution**: Update country/state probability distributions

#### 3. Schema Extensions
Add new fields by:
1. **Extending Base Class**: Add common fields to `BaseTransactionGenerator`
2. **Transaction-Specific**: Add fields to `FinancialTransactionGenerator` or `BrokerageTransactionGenerator`
3. **Schema Updates**: Update corresponding JSON schema files
4. **Database Schema**: Tables auto-created with new columns

#### 4. Performance Optimization
```bash
# Multi-threading for parallel generation
java -jar generator.jar --transaction-type both --num-records 50000
# Creates separate threads for financial and brokerage

# Memory optimization for large datasets
java -Xmx4g -jar generator.jar --num-records 1000000

# Database batch optimization
java -jar generator.jar --enable-database --num-records 100000 --interval 0
```

## Database Schema

### Automatic Table Creation
The system automatically creates appropriate table schemas based on transaction type:

- **Financial Transactions**: `financial_transactions` table with **101 columns**
  - Optimized data types for financial data (DECIMAL for amounts, VARCHAR for IDs)
  - Proper indexing on transaction_id, customer_id, and timestamp columns
  - Constraints for data integrity (NOT NULL, CHECK constraints)

- **Brokerage Transactions**: `brokerage_transactions` table with **180 columns**
  - Specialized data types for trading data (DECIMAL for prices, INTEGER for quantities)
  - Indexes on order_id, symbol, customer_id, and timestamp columns
  - Foreign key relationships and referential integrity

### Database-Specific Optimizations

#### PostgreSQL/Aurora PostgreSQL
- Uses PostgreSQL-specific data types (JSONB, TIMESTAMP WITH TIME ZONE)
- Optimized for ACID compliance and concurrent access
- Proper sequence generation for auto-incrementing IDs

#### Oracle Database
- Oracle-specific syntax and data types (NUMBER, VARCHAR2, TIMESTAMP)
- Sequence objects for primary key generation
- Oracle-optimized indexing strategies

#### CockroachDB
- Distributed database optimizations
- UUID primary keys for global uniqueness
- Optimized for horizontal scaling

### Dynamic Schema Management
- **Runtime Schema Detection**: Tables created based on actual generated fields
- **Data Type Mapping**: Automatic conversion between Java types and database types
- **Schema Evolution**: Support for adding new columns without breaking existing data
- **Validation**: Schema validation against JSON schema definitions

## Security

The module creates comprehensive IAM policies allowing the EC2 instance to:

### AWS Service Access
- **MSK Clusters**: Read/write access to Kafka topics with IAM authentication
- **Secrets Manager**: Read access to database connection secrets
- **S3 Assets**: Download access to the data generator JAR and source code
- **KMS Keys**: Decrypt access for encrypted secrets and S3 objects
- **Systems Manager**: Session Manager access for secure connections

### Network Security
- **VPC Integration**: Deployed in private subnets with no direct internet access
- **Security Groups**: Restrictive inbound rules, outbound access for AWS services
- **Database Connectivity**: Secure connections to databases within VPC
- **MSK Integration**: Secure connections to MSK clusters using IAM authentication

### Data Protection
- **Encryption in Transit**: All database and MSK connections use TLS/SSL
- **Encryption at Rest**: Secrets encrypted with KMS, S3 objects encrypted
- **Access Logging**: CloudTrail integration for audit trails
- **Least Privilege**: IAM roles follow principle of least privilege

## Dependencies

### Infrastructure Dependencies
- **VPC and Networking**: Private subnets, route tables, NAT gateways
- **MSK Cluster**: For Kafka publishing (if enabled)
- **Database Instances**: Oracle, Aurora, CockroachDB (if enabled)
- **S3 Assets Bucket**: For storing the generator JAR and source code
- **KMS Keys**: For encryption of secrets and S3 objects

### Service Dependencies
- **AWS Secrets Manager**: Database connection credentials
- **AWS Systems Manager**: Session Manager for secure connections
- **Amazon CloudWatch**: Logging and monitoring
- **AWS IAM**: Roles and policies for service access

### Build Dependencies
- **Java 21**: Amazon Corretto JDK for application runtime
- **Maven**: Build tool for compiling Java application
- **Kafka Client**: For MSK integration and topic management
- **JDBC Drivers**: Database-specific drivers for connectivity

## Outputs

The Terraform module provides the following outputs:

```hcl
# EC2 Instance Information
data_generator_instance_id     = "i-1234567890abcdef0"
data_generator_private_ip      = "10.0.1.100"

# Integration Status
oracle_integration_enabled     = true
aurora_integration_enabled     = true
cockroach_integration_enabled  = true
msk_integration_enabled        = true

# Secret Names (for reference)
oracle_secret_name             = "${APP_NAME}-${ENV_NAME}-oracle-secret"
aurora_secret_name             = "${APP_NAME}-${ENV_NAME}-aurora-secret"
cockroach_secret_name          = "${APP_NAME}-${ENV_NAME}-cockroach-secret"
msk_secret_name               = "${APP_NAME}-${ENV_NAME}-msk-secret"

# Table Names
oracle_financial_table_name    = "oracle_financial_transactions"
oracle_brokerage_table_name    = "oracle_brokerage_transactions"
aurora_financial_table_name    = "aurora_financial_transactions"
aurora_brokerage_table_name    = "aurora_brokerage_transactions"
```

## Benefits

### Technical Benefits
- **Maintainable Architecture**: Clean OOP design with minimal code duplication
- **Flexible Configuration**: Easy to add new transaction types or modify existing ones
- **Realistic Data**: Comprehensive, realistic transaction data for testing and development
- **Scalable Design**: Generic components support various use cases and high volumes
- **Database Agnostic**: Works seamlessly with multiple database engines
- **Rich Schema**: **101 columns** for financial and **180 columns** for brokerage transactions

### Operational Benefits
- **Automated Deployment**: Complete infrastructure and application setup
- **Conditional Configuration**: Only deploys components for enabled services
- **Secure by Default**: Comprehensive security controls and encryption
- **Monitoring Ready**: Built-in logging and monitoring capabilities
- **Easy Connectivity**: Session Manager integration for secure access

### Development Benefits
- **Comprehensive Testing**: Rich, realistic data for application testing
- **Performance Testing**: High-volume data generation capabilities
- **Schema Validation**: JSON schema definitions for data validation
- **Extensible Design**: Easy to add new fields, transaction types, or destinations

## Extensibility

The modular architecture makes it straightforward to extend:

### Adding New Transaction Types
1. **Create Generator Class**: Extend `BaseTransactionGenerator`
2. **Define Schema**: Create JSON schema file with field definitions
3. **Update Application**: Add new type to `EC2DataGeneratorApplication`
4. **Database Support**: Add table creation logic to `DatabaseTransactionWriter`

### Adding New Database Engines
1. **JDBC Driver**: Add database-specific JDBC driver dependency
2. **SQL Dialect**: Implement database-specific SQL generation
3. **Data Types**: Map Java types to database-specific data types
4. **Connection Logic**: Add connection string and authentication logic

### Adding New Output Formats
1. **Writer Interface**: Implement `DataWriter` interface
2. **Serialization**: Add support for new formats (Parquet, Avro, CSV)
3. **Configuration**: Add command-line options and configuration
4. **Integration**: Wire into main application flow

### Custom Field Generators
1. **Base Class Extension**: Add new methods to `BaseTransactionGenerator`
2. **Realistic Data**: Implement business logic for realistic data generation
3. **Correlation Logic**: Add correlations between related fields
4. **Validation**: Update JSON schemas with new field definitions

**📁 Source Code**: Complete Java source code available in [`generator/`](generator/) directory for customization and extension.
