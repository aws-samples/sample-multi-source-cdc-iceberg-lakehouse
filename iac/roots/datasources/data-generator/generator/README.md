# Transaction Data Generator

This Java application generates realistic transaction data for the Iceberg Data Lakehouse project. It supports both **financial transactions (101 columns)** and **brokerage transactions (180 columns)** with comprehensive, realistic data patterns. The application can output data to the console, publish it to Amazon MSK, or write it to relational databases.

## Features

- **Dual Transaction Types**: Financial (101 columns) and brokerage (180 columns) transaction generation
- **Realistic Data Generation**: Correlated fields with business logic and realistic distributions
- **Multiple Output Destinations**:
  - Console output with pretty-printed JSON
  - Amazon MSK publishing with IAM authentication
  - Relational database storage (PostgreSQL, Oracle, CockroachDB)
- **Flexible Generation Modes**: Fixed record count or continuous generation
- **Multi-threading Support**: Parallel processing for high-volume data generation
- **Configurable Parameters**: Extensive customization options for intervals, volumes, and patterns
- **Automatic Schema Management**: Dynamic table creation with appropriate data types

## Architecture

### Core Components

- **`EC2DataGeneratorApplication`**: Main application with comprehensive CLI interface
- **`BaseTransactionGenerator`**: Abstract base class with shared functionality
- **`FinancialTransactionGenerator`**: Generates 101-column financial transaction data
- **`BrokerageTransactionGenerator`**: Generates 180-column brokerage transaction data
- **`DatabaseTransactionWriter`**: Generic database writer supporting multiple engines
- **`MSKTransactionProducer`**: Kafka producer for MSK integration
- **`GenericDataGeneratorThread`**: Thread implementation for parallel processing

### Data Generation Patterns

#### Financial Transactions (101 Columns)
- **Core Transaction**: ID, amount, currency, status, timestamps
- **Customer Demographics**: Age, income, location, risk profile
- **Merchant Information**: Category, location, ratings, risk indicators
- **Payment Methods**: Card details, digital wallets, funding types
- **Risk & Fraud**: Fraud scores, behavioral patterns, velocity checks
- **Historical Analytics**: Transaction history, patterns, metrics

#### Brokerage Transactions (180 Columns)
- **Order Management**: Order types, sides, status, time in force
- **Security Details**: Symbols, exchanges, security types, identifiers
- **Account Information**: Account types, balances, buying power
- **Execution Data**: Prices, fills, venues, liquidity indicators
- **Risk & Compliance**: Pre/post-trade checks, regulatory IDs
- **Performance Analytics**: Latency, slippage, market impact

## Building the Application

### Prerequisites
- Java 21 (Amazon Corretto recommended)
- Maven 3.6+
- AWS CLI configured (for MSK/database integration)

### Build Process
```bash
cd iac/roots/datasources/data-generator/generator
mvn clean package
```

This creates an executable JAR with all dependencies:
`target/financial-transaction-generator-1.0-SNAPSHOT-jar-with-dependencies.jar`

## Running the Application

### Basic Usage
```bash
java -jar target/financial-transaction-generator-1.0-SNAPSHOT-jar-with-dependencies.jar [options]
```

### Command Line Options

#### General Options
- `--help`: Print comprehensive help message
- `--num-records <n>`: Number of records to generate (default: 5)
- `--interval <n>`: Interval between messages in ms (default: 1000)
- `--continuous`: Run continuously until duration expires
- `--duration <n>`: Duration in seconds for continuous mode (default: 60)
- `--region <s>`: AWS region (default: us-east-1)
- `--transaction-type <s>`: Transaction type: 'financial', 'brokerage', or 'both' (default: financial)

#### Console Output Options
- `--pretty-print`: Pretty print JSON output (default: true)
- `--no-pretty-print`: Disable pretty printing for compact output

#### MSK Publishing Options
- `--enable-msk`: Enable publishing to Amazon MSK
- `--bootstrap-servers-secret <s>`: Secret name containing MSK bootstrap servers
- `--topic <s>`: MSK topic name for publishing

#### Database Options
- `--enable-database`: Enable writing to relational database
- `--db-secret <s>`: Secret name containing database connection details
- `--table-name <s>`: Table name (auto-determined by transaction type if not specified)
- `--no-create-table`: Skip automatic table creation

## Usage Examples

### Console Output Mode

#### Basic Generation
```bash
# Generate 5 financial transactions (default)
java -jar generator.jar

# Generate 10 brokerage transactions
java -jar generator.jar --num-records 10 --transaction-type brokerage

# Generate both types (5 of each)
java -jar generator.jar --num-records 10 --transaction-type both

# Compact JSON output
java -jar generator.jar --num-records 3 --no-pretty-print
```

### MSK Publishing Mode

#### Single Transaction Type
```bash
# Publish financial transactions to MSK
java -jar generator.jar \
  --enable-msk \
  --bootstrap-servers-secret "msk-bootstrap-secret" \
  --topic "financial-transactions" \
  --transaction-type financial \
  --num-records 1000

# Continuous brokerage data streaming
java -jar generator.jar \
  --enable-msk \
  --bootstrap-servers-secret "msk-bootstrap-secret" \
  --topic "brokerage-transactions" \
  --transaction-type brokerage \
  --continuous \
  --duration 3600 \
  --interval 500
```

#### Both Transaction Types
```bash
# Publish both types to separate topics (parallel processing)
java -jar generator.jar \
  --enable-msk \
  --bootstrap-servers-secret "msk-bootstrap-secret" \
  --topic "all-transactions" \
  --transaction-type both \
  --num-records 5000 \
  --interval 100
```

### Database Mode

#### Single Database
```bash
# Write financial transactions to PostgreSQL
java -jar generator.jar \
  --enable-database \
  --db-secret "aurora-postgresql-secret" \
  --transaction-type financial \
  --table-name "financial_transactions" \
  --num-records 10000

# Write brokerage transactions to Oracle
java -jar generator.jar \
  --enable-database \
  --db-secret "oracle-database-secret" \
  --transaction-type brokerage \
  --table-name "brokerage_transactions" \
  --num-records 5000

# Continuous generation to CockroachDB
java -jar generator.jar \
  --enable-database \
  --db-secret "cockroach-secret" \
  --transaction-type both \
  --continuous \
  --duration 1800 \
  --interval 200
```

### Multi-Destination Mode

#### Database + MSK Simultaneously
```bash
# Write to both database and MSK in parallel
java -jar generator.jar \
  --enable-database \
  --db-secret "database-secret" \
  --enable-msk \
  --bootstrap-servers-secret "msk-secret" \
  --topic "financial-stream" \
  --transaction-type financial \
  --continuous \
  --duration 3600 \
  --interval 1000
```

## Configuration

### Database Configuration

The application uses AWS Secrets Manager for database credentials. The secret must contain:

```json
{
  "username": "trading_user",
  "password": "secure_password",  # pragma: allowlist secret
  "host": "database-host.region.rds.amazonaws.com",
  "port": "5432",
  "dbname": "trading_database",
  "engine": "postgresql"
}
```

#### Supported Database Engines
- `postgresql` or `postgres`: PostgreSQL/Aurora PostgreSQL
- `oracle`: Oracle Database
- `cockroachdb`: CockroachDB

### MSK Configuration

#### Authentication
- Uses AWS MSK IAM authentication by default
- Requires appropriate IAM permissions for MSK cluster access
- Bootstrap servers retrieved from AWS Secrets Manager

#### Topic Management
- Topics are automatically created if they don't exist
- Configurable partitioning and replication factors
- Support for multiple topics with different transaction types

## Data Structure

### Financial Transactions (101 Columns)
Generated data includes:
1. **Core Transaction Details** (15 columns): IDs, amounts, currencies, status
2. **Customer Demographics** (20 columns): Personal and financial profiles
3. **Merchant Information** (12 columns): Business details and risk indicators
4. **Payment Methods** (10 columns): Card details and funding types
5. **Location Data** (10 columns): IP geolocation and geographic patterns
6. **Risk & Fraud Analysis** (20 columns): Fraud scores and behavioral patterns
7. **Transaction History** (14 columns): Historical metrics and analytics

### Brokerage Transactions (180 Columns)
Generated data includes:
1. **Order Management** (25 columns): Order details, types, and status
2. **Security Information** (20 columns): Symbols, exchanges, and identifiers
3. **Account Details** (25 columns): Account types, balances, and customer info
4. **Execution Data** (30 columns): Pricing, fills, and venue information
5. **Risk & Compliance** (25 columns): Regulatory checks and compliance flags
6. **Performance Analytics** (35 columns): Latency, slippage, and market metrics
7. **Market Data** (20 columns): Real-time pricing and volatility indicators

## Performance Considerations

### Multi-threading
- Each destination (MSK, database) runs in separate threads
- Both transaction types processed in parallel when using `--transaction-type both`
- Configurable intervals prevent overwhelming target systems

### Memory Management
```bash
# For high-volume generation
java -Xmx4g -jar generator.jar --num-records 1000000

# For continuous streaming
java -Xms2g -Xmx8g -jar generator.jar --continuous --duration 86400
```

### Database Optimization
- Automatic table creation with appropriate indexes
- Batch processing for high-volume inserts
- Connection pooling for sustained operations

## Monitoring and Logging

### Logging Configuration
- Uses SLF4J with Logback implementation
- Configurable log levels via `src/main/resources/logback.xml`
- Structured logging for operational monitoring

### Key Metrics
- Records generated per second
- Database write performance
- MSK publish success rates
- Error rates and failure patterns

## Extensibility

### Adding New Transaction Types
1. Extend `BaseTransactionGenerator`
2. Implement `generateTransaction()` method
3. Add to `EC2DataGeneratorApplication` transaction type handling
4. Update command-line parsing and validation

### Adding New Destinations
1. Implement `DataWriter` interface
2. Add configuration parameters
3. Integrate into `createDataWriterGeneratorPairs()` method
4. Add command-line options and validation

### Custom Data Patterns
1. Modify generator classes for new field patterns
2. Update correlation logic in `BaseTransactionGenerator`
3. Adjust realistic data distributions
4. Add new validation rules and constraints

## Dependencies

### Core Dependencies
- **Jackson**: JSON processing and serialization
- **SLF4J/Logback**: Logging framework
- **AWS SDK v2**: Secrets Manager integration
- **Kafka Client**: MSK publishing capabilities

### Database Drivers
- **PostgreSQL**: `org.postgresql:postgresql:42.7.4`
- **Oracle**: `com.oracle.database.jdbc:ojdbc11:23.5.0.24.07` (provided scope, not bundled; see the repository README prerequisites)
- **MySQL**: `com.mysql:mysql-connector-j:8.4.0`
- **SQL Server**: `com.microsoft.sqlserver:mssql-jdbc:12.10.0.jre11`

### AWS Integration
- **MSK IAM Auth**: `software.amazon.msk:aws-msk-iam-auth:2.2.0`
- **Secrets Manager**: AWS SDK v2 for credential management
- **IAM Authentication**: Integrated AWS credential chain support
