# Oracle EC2 Scripts for DMS CDC

This directory contains scripts used for initializing and configuring Oracle EC2 instances optimized for AWS Database Migration Service (DMS) Change Data Capture (CDC) in the Iceberg Data Lakehouse project.

## Oracle CDC Overview

### What is Oracle CDC?

Change Data Capture (CDC) is a method of identifying and capturing changes made to data in a database and then delivering those changes in real-time to a downstream process or system. In Oracle, CDC works by reading the database's transaction logs (redo logs and archive logs) to capture INSERT, UPDATE, and DELETE operations.

### How Oracle CDC Works

Oracle CDC is fundamentally based on Oracle's Write-Ahead Logging (WAL) architecture, which ensures ACID compliance and provides the foundation for change data capture.

#### 1. **Oracle Transaction Logging Architecture**

Oracle uses a sophisticated multi-layered logging system:

**Write-Ahead Logging Principle**:

- All changes must be logged before they are applied to data files
- This ensures recoverability and provides the audit trail needed for CDC
- Changes are written to redo logs in chronological order with System Change Numbers (SCN)

**Transaction Flow**:

```
Application → SQL Statement → Parse → Execute → Redo Log Buffer → Redo Log Files → Data Files
                                           ↓
                                    Change Vectors
                                    (Before/After Images)
```

**Redo Log Structure**:

- **Redo Records**: Individual change entries containing operation type, SCN, timestamp, table/row identifiers
- **Change Vectors**: Before and after images of modified data
- **Transaction Boundaries**: BEGIN/COMMIT/ROLLBACK markers
- **DDL Operations**: Schema changes, table alterations, index modifications

#### 2. **System Change Number (SCN) - The Heart of Oracle CDC**

SCN is Oracle's internal clock that provides:

- **Monotonic Ordering**: Ensures changes are processed in correct sequence
- **Consistency Point**: Defines a consistent state of the database
- **Recovery Coordination**: Enables point-in-time recovery
- **CDC Positioning**: Allows CDC tools to resume from specific points

**SCN Lifecycle**:

```
Transaction Start → SCN Assignment → Redo Generation → SCN Commit → Archive
```

#### 3. **Redo Log Lifecycle and CDC Implications**

**Online Redo Logs**:

- **Current Log**: Actively being written by LGWR (Log Writer) process
- **Active Logs**: Recently written, may contain uncommitted transactions
- **Inactive Logs**: Completed logs ready for archiving

**Archive Logs**:

- **Archival Process**: ARCn processes copy online redo logs to archive destination
- **Retention**: Historical logs maintained for recovery and CDC
- **Accessibility**: CDC tools read from both online and archived logs

**Log Switch Triggers**:

1. **Size-based**: When current log fills up (default 200MB in Oracle XE)
2. **Time-based**: `archive_lag_target` parameter forces switches
3. **Manual**: `ALTER SYSTEM SWITCH LOGFILE` command
4. **Checkpoint**: Database checkpoint operations

#### 4. **Supplemental Logging - Critical for CDC**

Standard redo logs contain minimal information. Supplemental logging adds essential CDC data:

**Minimal Supplemental Logging**:

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
```

- Adds primary key information to all redo records
- Ensures unique row identification in CDC streams
- Required for all CDC implementations

**Primary Key Supplemental Logging**:

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS;
```

- Logs primary key values for all DML operations
- Critical for UPDATE operations to identify affected rows
- Enables proper change ordering and deduplication

**All Columns Supplemental Logging**:

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```

- Logs all column values for changed rows
- Provides complete before/after images
- Essential for comprehensive CDC scenarios
- Increases redo log volume but ensures data completeness

**Table-Level Supplemental Logging**:

```sql
ALTER TABLE schema.table ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```

- Granular control over supplemental logging
- Reduces overhead for non-CDC tables
- Allows customization per table requirements

#### 5. **Change Vector Analysis**

Each redo record contains change vectors with:

**DML Operations**:

- **INSERT**: New row data with all column values
- **UPDATE**: Before and after images of changed columns
- **DELETE**: Complete row data being removed

**Change Vector Components**:

```
Change Vector:
├── Operation Type (INSERT/UPDATE/DELETE)
├── SCN (System Change Number)
├── Timestamp
├── Transaction ID
├── Object ID (Table identifier)
├── Rowid (Physical row location)
├── Column Data
│   ├── Before Image (for UPDATE/DELETE)
│   └── After Image (for INSERT/UPDATE)
└── Supplemental Data
    ├── Primary Key values
    ├── Unique Key values
    └── Additional logged columns
```

#### 6. **LogMiner vs Binary Reader - Deep Technical Comparison**

**LogMiner Method**:

- **Architecture**: SQL-based interface to redo log analysis
- **Process**: Parses redo logs into `V$LOGMNR_CONTENTS` view
- **Advantages**:
  - Standard Oracle API
  - SQL-queryable interface
  - Built-in filtering capabilities
  - Automatic handling of log file management
- **Disadvantages**:
  - Higher CPU overhead (parsing + SQL processing)
  - Memory intensive (dictionary loading)
  - Slower performance for high-volume changes
  - Requires LogMiner privileges and setup

**Binary Reader Method** (Used in this project):

- **Architecture**: Direct binary parsing of redo log files
- **Process**: Reads raw redo log blocks and interprets change vectors
- **Advantages**:
  - Lower CPU overhead (direct binary access)
  - Faster processing (no SQL layer)
  - Better performance for high-volume CDC
  - Lower memory footprint
- **Disadvantages**:
  - Requires file system access to redo logs
  - More complex configuration
  - Direct dependency on Oracle internal formats
  - Needs proper file permissions and paths

#### 7. **ARCHIVELOG Mode - Foundation for CDC**

**NOARCHIVELOG Mode Limitations**:

- Online redo logs are overwritten cyclically
- No historical change data available
- CDC impossible beyond current online logs
- Recovery limited to last backup

**ARCHIVELOG Mode Benefits**:

- All redo logs archived before overwriting
- Complete change history maintained
- Point-in-time recovery possible
- CDC can access historical changes
- Continuous data protection

**Archive Log Management**:

```sql
-- Configure archive destination
ALTER SYSTEM SET log_archive_dest_1='LOCATION=/opt/oracle/oradata/XE/archive' SCOPE=BOTH;

-- Set archive format for unique naming
ALTER SYSTEM SET log_archive_format='arch_%t_%s_%r.arc' SCOPE=SPFILE;

-- Enable automatic archiving
ALTER SYSTEM SET log_archive_start=TRUE SCOPE=SPFILE;
```

### Oracle CDC Architecture Components

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Application   │───▶│    Oracle    │───▶│   Redo Logs     │
│   (Inserts/     │    │   Database   │    │   (Online &     │
│   Updates/      │    │              │    │   Archived)     │
│   Deletes)      │    │              │    │                 │
└─────────────────┘    └──────────────┘    └─────────────────┘
                                                     │
                                                     ▼
                                           ┌─────────────────┐
                                           │   CDC Reader    │
                                           │   (DMS/         │
                                           │   LogMiner/     │
                                           │   Binary)       │
                                           └─────────────────┘
                                                     │
                                                     ▼
                                           ┌─────────────────┐
                                           │   Target        │
                                           │   (MSK/Kafka/   │
                                           │   S3/etc.)      │
                                           └─────────────────┘
```

## AWS DMS CDC Integration

### How DMS Works with Oracle CDC

AWS Database Migration Service (DMS) provides two methods for Oracle CDC:

#### 1. **LogMiner Method** (`useLogminerReader=Y`)

- Uses Oracle's built-in LogMiner API
- Queries `V$LOGMNR_CONTENTS` view to read changes
- Requires LogMiner privileges for the DMS user
- More resource-intensive but easier to configure

#### 2. **Binary Reader Method** (`useBfile=Y`) - **Used in this project**

- Directly reads Oracle redo log files
- Bypasses LogMiner for better performance
- Requires file system access to redo logs
- Lower overhead, faster processing

### DMS CDC Prerequisites

For DMS CDC to work with Oracle, several requirements must be met:

1. **ARCHIVELOG Mode**: Database must be in ARCHIVELOG mode
2. **Supplemental Logging**: Must be enabled at database and table levels
3. **Primary Keys**: Tables must have primary keys for CDC
4. **Permissions**: DMS user needs specific privileges
5. **Archive Log Access**: DMS needs access to archive log files

## Scripts Overview

### user_data.sh

This script is executed when an Oracle EC2 instance is launched and performs comprehensive Oracle setup optimized for DMS CDC:

#### Core Installation Tasks:

1. **System Setup**: Updates system and installs required packages
2. **Oracle Installation**: Downloads and installs Oracle 21c Express Edition
3. **Database Configuration**: Sets up Oracle with CDC-optimized parameters
4. **User Creation**: Creates `ORACLE_USER` (application), `C##DBZUSER` (Debezium), `C##DMSUSER` (DMS)
5. **CDC Optimization**: Configures Oracle for optimal DMS CDC performance

#### CDC-Specific Configuration:

##### 1. **ARCHIVELOG Mode Setup**

```sql
-- Enable ARCHIVELOG mode (required for CDC)
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```

##### 2. **Archive Log Destination Configuration**

```sql
-- Configure archive log destination for DMS access
ALTER SYSTEM SET log_archive_dest_1='LOCATION=/opt/oracle/oradata/XE/archive' SCOPE=BOTH;
ALTER SYSTEM SET log_archive_dest_state_1=ENABLE SCOPE=BOTH;
```

##### 3. **Supplemental Logging Enablement**

```sql
-- Enable supplemental logging globally
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```

##### 4. **CDC Performance Optimization - Deep Analysis**

The script includes an inline SQL optimization block that addresses fundamental Oracle logging bottlenecks:

###### **Redo Log Size Optimization**

**Problem with Large Redo Logs (200MB default)**:

- **Log Switch Frequency**: Oracle switches logs only when current log is full
- **Change Availability**: CDC tools can only read completed (switched) logs
- **Latency Impact**: With low transaction volume, 200MB logs may take hours to fill
- **CDC Starvation**: Changes trapped in current log until switch occurs

**Solution with Smaller Redo Logs (50MB)**:

```sql
-- Add smaller redo logs for faster CDC response
ALTER DATABASE ADD LOGFILE GROUP 4 '/opt/oracle/oradata/XE/redo04.log' SIZE 50M;
ALTER DATABASE ADD LOGFILE GROUP 5 '/opt/oracle/oradata/XE/redo05.log' SIZE 50M;
ALTER DATABASE ADD LOGFILE GROUP 6 '/opt/oracle/oradata/XE/redo06.log' SIZE 50M;
```

**Mathematical Impact**:

- **200MB logs**: At 1MB/hour transaction rate = 200 hours to switch
- **50MB logs**: At 1MB/hour transaction rate = 50 hours to switch
- **With archive_lag_target**: Maximum 30 seconds regardless of transaction volume

###### **Archive Lag Target - Time-Based Log Switching**

```sql
-- Configure automatic log switching (every 30 seconds)
ALTER SYSTEM SET archive_lag_target = 30 SCOPE=BOTH;
```

**Mechanism**:

- **ARCH Process Monitoring**: Archive processes monitor log age
- **Forced Switches**: Triggers log switch if current log exceeds lag target
- **SCN Advancement**: Ensures continuous SCN progression for CDC
- **Low-Volume Protection**: Prevents CDC starvation during quiet periods

**Trade-offs**:

- **Benefits**: Guaranteed CDC latency, consistent change availability
- **Costs**: Increased archive log volume, more frequent I/O operations
- **Configured Value**: 30 seconds prioritizes low CDC latency over log-switch overhead

###### **Log Buffer Optimization**

```sql
-- Enable fast log writer for better performance
ALTER SYSTEM SET log_buffer = 8388608 SCOPE=SPFILE;  -- 8MB
```

**Log Buffer Mechanics**:

- **User Process**: Writes redo entries to log buffer in SGA
- **LGWR Process**: Flushes buffer to online redo logs
- **Trigger Conditions**:
  - Buffer 1/3 full
  - 3 seconds elapsed
  - Transaction commits
  - Before DBWR writes dirty buffers

**Optimization Impact**:

- **Larger Buffer**: Reduces LGWR write frequency
- **Batch Efficiency**: More redo entries per I/O operation
- **CDC Benefit**: Faster redo generation means quicker change availability
- **Memory Trade-off**: Uses more SGA memory for better I/O performance

###### **Checkpoint Optimization**

```sql
-- Configure checkpoint frequency for better CDC performance
ALTER SYSTEM SET fast_start_mttr_target = 60 SCOPE=BOTH;  -- 60 seconds
```

**Checkpoint Process**:

- **CKPT Process**: Coordinates checkpoint operations
- **DBWR Process**: Writes dirty buffers to data files
- **SCN Advancement**: Updates control file with checkpoint SCN
- **Recovery Window**: Limits redo needed for instance recovery

**CDC Relationship**:

- **Faster Checkpoints**: More frequent SCN advancement
- **Redo Availability**: Older redo logs can be archived sooner
- **CDC Consistency**: Ensures consistent read points for CDC tools
- **Recovery Efficiency**: Faster instance recovery if needed

###### **Comprehensive Performance Impact Analysis**

**Before Optimization**:

```
Transaction → Redo Buffer → 200MB Log → Hours to Switch → Archive → CDC Access
Timeline:     Immediate    Immediate    2-24 hours      +Minutes   +Processing
```

**After Optimization**:

```
Transaction → Redo Buffer → 50MB Log → Max 2 Minutes → Archive → CDC Access
Timeline:     Immediate    Immediate    0-30 seconds    +Seconds   +Processing
```

**Quantitative Benefits**:

- **CDC Latency**: Reduced from hours to minutes (99%+ improvement)
- **Change Availability**: Guaranteed within 30 seconds
- **Throughput**: Higher CDC processing rate due to consistent flow
- **Reliability**: Eliminates CDC starvation scenarios

**Resource Implications**:

- **Archive Storage**: 4x more archive logs (due to smaller size + time triggers)
- **I/O Operations**: More frequent but smaller log switches
- **CPU Usage**: Slightly higher due to more frequent archive operations
- **Memory Usage**: 8MB additional SGA for log buffer

## DMS CDC Configuration Details

### Binary File Reader Configuration

The DMS endpoint is configured to use Binary File Reader (`useBfile=Y`) for optimal performance:

```terraform
extra_connection_attributes = "useLogminerReader=N;useBfile=Y;addSupplementalLogging=Y;accessAlternateDirectly=false;useAlternateFolderForOnline=true;oraclePathPrefix=/opt/oracle/oradata/XE;usePathPrefix=/opt/oracle/oradata/XE"
```

#### Key Parameters:

- `useLogminerReader=N`: Disables LogMiner method
- `useBfile=Y`: Enables Binary File Reader for direct log access
- `addSupplementalLogging=Y`: Automatically adds supplemental logging
- `oraclePathPrefix`: Specifies path to Oracle data files
- `usePathPrefix`: Path for DMS to locate redo logs

### DMS CDC Process Flow - Detailed Technical Analysis

#### **Phase 1: Initial Setup and Discovery**

**Connection Establishment**:

- **Authentication**: DMS connects as SYSTEM user with elevated privileges
- **Session Configuration**: Sets session parameters for optimal CDC performance
- **Privilege Verification**: Validates required permissions for log access
- **Network Optimization**: Configures connection pooling and timeout settings

**Table Discovery Process**:

```sql
-- DMS queries system tables to discover CDC candidates
SELECT owner, table_name, num_rows, last_analyzed
FROM dba_tables
WHERE owner = 'ORACLE_USER'
AND table_name LIKE '%';

-- Validates primary key constraints
SELECT constraint_name, column_name, position
FROM dba_cons_columns
WHERE owner = 'ORACLE_USER'
AND constraint_name IN (
  SELECT constraint_name FROM dba_constraints
  WHERE constraint_type = 'P'
);
```

#### **Phase 2: Baseline Load (Full Load)**

**Snapshot Consistency**:

- **SCN Capture**: Records current SCN as consistency point
- **Flashback Query**: Uses `AS OF SCN` to ensure consistent read
- **Parallel Processing**: Splits large tables into chunks for parallel extraction
- **Progress Tracking**: Monitors row counts and completion percentage

**Data Extraction Strategy**:

```sql
-- Example of DMS full load query with SCN consistency
SELECT /*+ PARALLEL(4) */ *
FROM ORACLE_USER.financial_transactions
AS OF SCN :baseline_scn
WHERE rownum BETWEEN :start_row AND :end_row;
```

#### **Phase 3: CDC Initialization**

**SCN Positioning**:

- **Starting SCN**: Establishes CDC starting point (usually baseline SCN + 1)
- **Log File Mapping**: Identifies which archive logs contain the starting SCN
- **Recovery Validation**: Ensures all required logs are accessible
- **Checkpoint Creation**: Records initial position for restart capability

**Binary Reader Initialization**:

```
DMS Binary Reader Process:
├── Log File Discovery
│   ├── Scan archive log directory
│   ├── Identify logs containing starting SCN
│   └── Build chronological log sequence
├── Log File Validation
│   ├── Verify file accessibility
│   ├── Check file integrity
│   └── Validate SCN ranges
└── Reader Thread Startup
    ├── Initialize log parsing engine
    ├── Set up change vector processing
    └── Begin continuous monitoring
```

#### **Phase 4: Continuous Change Monitoring**

**Log File Processing Cycle**:

1. **File Detection**: Monitor for new archive logs and online log switches
2. **Sequential Reading**: Process logs in SCN order to maintain consistency
3. **Change Vector Parsing**: Extract individual change records from redo blocks
4. **Transaction Assembly**: Group related changes by transaction ID
5. **Commit Processing**: Apply changes only after transaction commits

**Change Vector Analysis**:

```
Redo Record Structure:
├── Record Header
│   ├── SCN (System Change Number)
│   ├── Timestamp
│   ├── Transaction ID
│   └── Operation Type
├── Object Information
│   ├── Object ID (Table)
│   ├── Data Object ID
│   ├── Tablespace ID
│   └── Block Address
├── Row Information
│   ├── Rowid
│   ├── Slot Number
│   └── Row Flags
└── Column Data
    ├── Before Image (UPDATE/DELETE)
    ├── After Image (INSERT/UPDATE)
    └── Supplemental Logging Data
```

#### **Phase 5: Change Processing and Transformation**

**DML Operation Processing**:

**INSERT Operations**:

```json
{
  "operation": "INSERT",
  "scn": "1234567890",
  "timestamp": "2025-01-27T10:30:45.123Z",
  "transaction_id": "0x000a.012.00000345",
  "table": "ORACLE_USER.FINANCIAL_TRANSACTIONS",
  "primary_key": { "TRANSACTION_ID": "TXN_001" },
  "after_image": {
    "TRANSACTION_ID": "TXN_001",
    "TRANSACTION_TYPE": "PURCHASE",
    "AMOUNT": 150.0
  }
}
```

**UPDATE Operations**:

```json
{
  "operation": "UPDATE",
  "scn": "1234567891",
  "timestamp": "2025-01-27T10:31:15.456Z",
  "transaction_id": "0x000a.012.00000346",
  "table": "ORACLE_USER.FINANCIAL_TRANSACTIONS",
  "primary_key": { "TRANSACTION_ID": "TXN_001" },
  "before_image": {
    "AMOUNT": 150.0,
    "STATUS": "PENDING"
  },
  "after_image": {
    "AMOUNT": 150.0,
    "STATUS": "COMPLETED"
  }
}
```

**DELETE Operations**:

```json
{
  "operation": "DELETE",
  "scn": "1234567892",
  "timestamp": "2025-01-27T10:32:00.789Z",
  "transaction_id": "0x000a.012.00000347",
  "table": "ORACLE_USER.FINANCIAL_TRANSACTIONS",
  "primary_key": { "TRANSACTION_ID": "TXN_001" },
  "before_image": {
    "TRANSACTION_ID": "TXN_001",
    "TRANSACTION_TYPE": "PURCHASE",
    "AMOUNT": 150.0,
    "STATUS": "COMPLETED"
  }
}
```

**DDL Operation Processing**:

```json
{
  "operation": "DDL",
  "scn": "1234567893",
  "timestamp": "2025-01-27T10:33:00.000Z",
  "ddl_type": "ALTER_TABLE",
  "table": "ORACLE_USER.FINANCIAL_TRANSACTIONS",
  "ddl_statement": "ALTER TABLE FINANCIAL_TRANSACTIONS ADD COLUMN NEW_FIELD VARCHAR2(100)"
}
```

#### **Phase 6: Target Delivery to MSK/Kafka**

**Message Formatting**:

- **Avro Serialization**: Converts change records to Avro format
- **Schema Registry**: Manages schema evolution and compatibility
- **Partitioning Strategy**: Routes messages based on primary key hash
- **Ordering Guarantee**: Maintains change order within partitions

**Delivery Guarantees**:

- **At-Least-Once**: Ensures no change records are lost
- **Idempotency**: Handles duplicate delivery scenarios
- **Error Handling**: Implements retry logic with exponential backoff
- **Dead Letter Queue**: Captures unprocessable messages

**Performance Optimization**:

- **Batch Processing**: Groups multiple changes into single Kafka messages
- **Compression**: Reduces network overhead with gzip/snappy compression
- **Async Delivery**: Non-blocking message production for higher throughput
- **Connection Pooling**: Reuses Kafka connections for efficiency

---

## Deep Dive: Oracle Logging Architecture and Change Types

### Oracle Write-Ahead Logging (WAL) - The Foundation of CDC

Oracle's Write-Ahead Logging is a sophisticated system that ensures ACID compliance while providing the foundation for Change Data Capture. Understanding this architecture is crucial for optimizing CDC performance.

#### **The Oracle Logging Stack - Layer by Layer Analysis**

```
Application Layer
    ↓
SQL Processing Layer (Parse, Optimize, Execute)
    ↓
Transaction Management Layer (Lock, Rollback Segments)
    ↓
Redo Generation Layer (Change Vectors, Before/After Images)
    ↓
Log Buffer Layer (In-Memory Staging)
    ↓
Log Writer Process (LGWR)
    ↓
Online Redo Logs (Circular Buffer)
    ↓
Archive Process (ARCn)
    ↓
Archive Logs (Permanent Storage)
    ↓
CDC Readers (DMS, LogMiner, etc.)
```

#### **Redo Record Anatomy - What Gets Logged**

Every change in Oracle generates redo records with intricate detail:

```
Redo Record Header:
├── Record Type (INSERT/UPDATE/DELETE/DDL/COMMIT/ROLLBACK)
├── SCN (System Change Number) - 48-bit monotonic counter
├── Timestamp - Precise to microseconds
├── Thread Number - RAC instance identifier
├── Sequence Number - Log file sequence
├── Block Address - Physical location in data file
├── Transaction ID - Unique transaction identifier
├── Previous Record Address - Linked list structure
└── Record Length - Variable length record size

Change Vector Components:
├── Operation Code (OpCode)
│   ├── 5.1 = INSERT operation
│   ├── 5.2 = DELETE operation
│   ├── 5.4 = UPDATE operation
│   ├── 5.6 = LOCK operation
│   └── 5.8 = COMMIT operation
├── Object Information
│   ├── Object ID (OBJ#) - Internal table identifier
│   ├── Data Object ID (DATAOBJ#) - Partition identifier
│   ├── Tablespace ID (TS#) - Tablespace number
│   └── Relative File Number (RFILE#) - Data file identifier
├── Row Information
│   ├── Block Number (BLOCK#) - Block within file
│   ├── Slot Number (SLOT#) - Row slot within block
│   ├── Row Flags - Row state indicators
│   └── Row Directory Entry - Row location metadata
└── Column Data
    ├── Column Count - Number of columns affected
    ├── Column Numbers - Which columns changed
    ├── Column Lengths - Variable length indicators
    ├── Before Image - Original values (UPDATE/DELETE)
    ├── After Image - New values (INSERT/UPDATE)
    └── Null Indicators - NULL value flags
```

#### **System Change Number (SCN) - Oracle's Global Clock**

SCN is Oracle's internal timestamp mechanism that provides total ordering of all database changes:

**SCN Structure (48-bit value)**:

```
Bits 47-32: Base SCN (increments every ~16M operations)
Bits 31-16: Wrap Counter (handles SCN wraparound)
Bits 15-0:  Sequence Number (fine-grained ordering)
```

**SCN Assignment Process**:

1. **Transaction Start**: No SCN assigned yet (transaction in progress)
2. **First Change**: SCN allocated from SGA's SCN generator
3. **Subsequent Changes**: Same SCN used for all changes in transaction
4. **Commit Time**: Final SCN assigned (commit SCN)
5. **Global Broadcast**: SCN propagated to all instances (RAC)

**SCN Advancement Triggers**:

- **Transaction Commits**: Most common SCN advancement
- **DDL Operations**: Always generate new SCN
- **Checkpoint Operations**: Advance SCN for consistency
- **Log Switches**: May advance SCN for coordination
- **Time-based**: Automatic advancement every 3 seconds minimum

**SCN in CDC Context**:

```sql
-- Current SCN (what CDC tools use as "now")
SELECT current_scn FROM v$database;

-- SCN to timestamp conversion (critical for CDC ordering)
SELECT scn_to_timestamp(1234567890) FROM dual;

-- Timestamp to SCN conversion (for point-in-time CDC)
SELECT timestamp_to_scn(SYSTIMESTAMP - INTERVAL '1' HOUR) FROM dual;
```

### Change Types and Their CDC Implications

#### **DML Operations - Data Manipulation Language**

##### **INSERT Operations - Complete Row Capture**

**Redo Record Structure for INSERT**:

```
INSERT Redo Record:
├── OpCode: 5.1 (INSERT)
├── Object Info: Table OBJ#, DATAOBJ#, TS#
├── Block Info: BLOCK#, SLOT#
├── Row Header: Row flags, column count
├── Column Data: All column values (complete row)
├── Supplemental Data: Primary key, unique keys
└── Transaction Context: XID, SCN, timestamp
```

**Why INSERTs are CDC-Friendly**:

- **Complete Data**: All column values available in redo
- **No Before Image**: Simpler processing (only after image)
- **Primary Key**: Always logged for row identification
- **Minimal Ambiguity**: Clear operation semantics

**INSERT CDC Processing Example**:

```json
{
  "operation": "INSERT",
  "scn": "1234567890",
  "timestamp": "2025-01-27T10:30:45.123456Z",
  "transaction_id": "0x000a.012.00000345",
  "table": {
    "owner": "ORACLE_USER",
    "name": "FINANCIAL_TRANSACTIONS",
    "object_id": 12345
  },
  "row_id": "AAAMzKAAEAAAAFaAAA",
  "primary_key": {
    "TRANSACTION_ID": "TXN_20250127_001"
  },
  "after_image": {
    "TRANSACTION_ID": "TXN_20250127_001",
    "TRANSACTION_TYPE": "PURCHASE",
    "AMOUNT": 150.0,
    "CURRENCY": "USD",
    "MERCHANT_ID": "MERCH_001",
    "CUSTOMER_ID": "CUST_12345",
    "STATUS": "PENDING",
    "DESCRIPTION": "Online purchase at Example Store"
  },
  "supplemental_logging": {
    "all_columns": true,
    "primary_key_logged": true,
    "unique_keys_logged": ["UK_TRANSACTION_REF"]
  }
}
```

##### **UPDATE Operations - Before/After Image Complexity**

**Redo Record Structure for UPDATE**:

```
UPDATE Redo Record:
├── OpCode: 5.4 (UPDATE)
├── Object Info: Table OBJ#, DATAOBJ#, TS#
├── Block Info: BLOCK#, SLOT# (same row, different values)
├── Row Header: Row flags, column count
├── Before Image: Original column values (changed columns only)
├── After Image: New column values (changed columns only)
├── Unchanged Columns: May be logged based on supplemental logging
├── Supplemental Data: Primary key, unique keys, additional columns
└── Transaction Context: XID, SCN, timestamp
```

**UPDATE Complexity Factors**:

1. **Partial Column Logging**: Only changed columns in basic redo
2. **Supplemental Logging Impact**: Additional columns logged for CDC
3. **Primary Key Changes**: Rare but complex (effectively DELETE + INSERT)
4. **Large Object Updates**: LOB columns handled differently
5. **Chained Row Updates**: Updates spanning multiple blocks

**UPDATE CDC Processing Example**:

```json
{
  "operation": "UPDATE",
  "scn": "1234567891",
  "timestamp": "2025-01-27T10:31:15.456789Z",
  "transaction_id": "0x000a.012.00000346",
  "table": {
    "owner": "ORACLE_USER",
    "name": "FINANCIAL_TRANSACTIONS",
    "object_id": 12345
  },
  "row_id": "AAAMzKAAEAAAAFaAAA",
  "primary_key": {
    "TRANSACTION_ID": "TXN_20250127_001"
  },
  "before_image": {
    "STATUS": "PENDING",
    "UPDATED_AT": null,
    "PROCESSING_TIME": null
  },
  "after_image": {
    "STATUS": "COMPLETED",
    "UPDATED_AT": "2025-01-27T10:31:15.000000Z",
    "PROCESSING_TIME": 45.5
  },
  "unchanged_columns": {
    "TRANSACTION_ID": "TXN_20250127_001",
    "TRANSACTION_TYPE": "PURCHASE",
    "AMOUNT": 150.0,
    "CURRENCY": "USD",
    "MERCHANT_ID": "MERCH_001",
    "CUSTOMER_ID": "CUST_12345",
    "DESCRIPTION": "Online purchase at Example Store"
  },
  "supplemental_logging": {
    "all_columns": true,
    "changed_columns_only": false,
    "primary_key_logged": true
  }
}
```

**Critical UPDATE Scenarios for CDC**:

1. **Primary Key Updates** (Rare but Critical):

```sql
-- This generates complex redo patterns
UPDATE financial_transactions
SET transaction_id = 'TXN_20250127_001_CORRECTED'
WHERE transaction_id = 'TXN_20250127_001';
```

CDC sees this as:

```json
[
  {
    "operation": "DELETE",
    "primary_key": { "TRANSACTION_ID": "TXN_20250127_001" },
    "before_image": {
      /* complete row */
    }
  },
  {
    "operation": "INSERT",
    "primary_key": { "TRANSACTION_ID": "TXN_20250127_001_CORRECTED" },
    "after_image": {
      /* complete row with new PK */
    }
  }
]
```

2. **Multi-Column Updates**:

```sql
UPDATE financial_transactions
SET status = 'REFUNDED',
    refund_amount = 150.00,
    refund_date = SYSTIMESTAMP,
    updated_at = SYSTIMESTAMP
WHERE transaction_id = 'TXN_20250127_001';
```

##### **DELETE Operations - Complete Row Preservation**

**Redo Record Structure for DELETE**:

```
DELETE Redo Record:
├── OpCode: 5.2 (DELETE)
├── Object Info: Table OBJ#, DATAOBJ#, TS#
├── Block Info: BLOCK#, SLOT# (row being removed)
├── Row Header: Row flags, column count
├── Before Image: Complete row data (all columns)
├── Supplemental Data: Primary key, unique keys
├── Row Directory: Slot marked as deleted
└── Transaction Context: XID, SCN, timestamp
```

**Why DELETEs are CDC-Critical**:

- **Complete Row Capture**: All column values preserved in redo
- **Irreversible Operation**: No "after image" - row is gone
- **Referential Integrity**: May trigger cascade deletes
- **Audit Requirements**: Often need complete deleted row data

**DELETE CDC Processing Example**:

```json
{
  "operation": "DELETE",
  "scn": "1234567892",
  "timestamp": "2025-01-27T10:32:00.789123Z",
  "transaction_id": "0x000a.012.00000347",
  "table": {
    "owner": "ORACLE_USER",
    "name": "FINANCIAL_TRANSACTIONS",
    "object_id": 12345
  },
  "row_id": "AAAMzKAAEAAAAFaAAA",
  "primary_key": {
    "TRANSACTION_ID": "TXN_20250127_001"
  },
  "before_image": {
    "TRANSACTION_ID": "TXN_20250127_001",
    "TRANSACTION_TYPE": "PURCHASE",
    "AMOUNT": 150.0,
    "CURRENCY": "USD",
    "MERCHANT_ID": "MERCH_001",
    "CUSTOMER_ID": "CUST_12345",
    "UPDATED_AT": "2025-01-27T10:31:15.000000Z",
    "STATUS": "COMPLETED",
    "PROCESSING_TIME": 45.5,
    "DESCRIPTION": "Online purchase at Example Store"
  },
  "after_image": null,
  "deletion_reason": "CUSTOMER_REQUESTED_REMOVAL",
  "cascade_effects": [
    {
      "table": "TRANSACTION_AUDIT_LOG",
      "operation": "INSERT",
      "description": "Audit record for deleted transaction"
    }
  ]
}
```

#### **DDL Operations - Data Definition Language**

DDL operations are particularly challenging for CDC because they change the structure of data, not just the data itself.

##### **Table Structure Changes**

**ALTER TABLE ADD COLUMN**:

```sql
ALTER TABLE financial_transactions
ADD (
    risk_score NUMBER(5,2),
    risk_category VARCHAR2(20),
    evaluated_at TIMESTAMP
);
```

**DDL Redo Record Structure**:

```
DDL Redo Record:
├── OpCode: 5.14 (DDL)
├── DDL Type: ALTER_TABLE
├── Object Info: Table OBJ#, new DATAOBJ# (structure change)
├── DDL Statement: Complete SQL text
├── Schema Version: Before/after schema versions
├── Column Metadata: New column definitions
├── Default Values: Default values for new columns
├── Constraint Changes: New constraints, indexes
└── Transaction Context: XID, SCN, timestamp
```

**CDC Impact of DDL**:

1. **Schema Evolution**: CDC tools must adapt to new table structure
2. **Backward Compatibility**: Existing data doesn't have new columns
3. **Default Value Handling**: New columns get default values
4. **Index Implications**: New indexes may affect performance
5. **Constraint Validation**: New constraints validated against existing data

**DDL CDC Processing Example**:

```json
{
  "operation": "DDL",
  "scn": "1234567893",
  "timestamp": "2025-01-27T10:33:00.000000Z",
  "ddl_type": "ALTER_TABLE",
  "table": {
    "owner": "ORACLE_USER",
    "name": "FINANCIAL_TRANSACTIONS",
    "object_id": 12345,
    "new_object_id": 12346
  },
  "ddl_statement": "ALTER TABLE financial_transactions ADD (risk_score NUMBER(5,2), risk_category VARCHAR2(20), evaluated_at TIMESTAMP)",
  "schema_changes": {
    "columns_added": [
      {
        "name": "RISK_SCORE",
        "data_type": "NUMBER",
        "precision": 5,
        "scale": 2,
        "nullable": true,
        "default_value": null
      },
      {
        "name": "RISK_CATEGORY",
        "data_type": "VARCHAR2",
        "length": 20,
        "nullable": true,
        "default_value": null
      },
      {
        "name": "EVALUATED_AT",
        "data_type": "TIMESTAMP",
        "nullable": true,
        "default_value": null
      }
    ]
  },
  "cdc_implications": {
    "schema_registry_update_required": true,
    "existing_records_affected": false,
    "new_records_include_columns": true,
    "backward_compatibility": "maintained"
  }
}
```

##### **Index Operations**

**CREATE INDEX**:

```sql
CREATE INDEX idx_financial_amount_status
ON financial_transactions(amount, status)
TABLESPACE users;
```

**Index DDL Impact on CDC**:

- **Performance Changes**: May affect DML operation speed
- **Redo Volume**: Index maintenance generates additional redo
- **Lock Duration**: Brief locks during index creation
- **Space Usage**: Additional storage requirements

##### **Constraint Operations**

**ADD CONSTRAINT**:

```sql
ALTER TABLE financial_transactions
ADD CONSTRAINT chk_amount_positive
CHECK (amount > 0);
```

**Constraint Impact on CDC**:

- **Data Validation**: New constraints validate existing data
- **DML Restrictions**: Future changes must satisfy constraints
- **Error Handling**: Constraint violations may affect CDC processing
- **Rollback Scenarios**: Failed constraints generate rollback redo

#### **Transaction Control Operations**

##### **COMMIT Operations**

**COMMIT Redo Record**:

```
COMMIT Redo Record:
├── OpCode: 5.8 (COMMIT)
├── Transaction ID: XID being committed
├── Commit SCN: Final SCN for transaction
├── Commit Timestamp: Precise commit time
├── Transaction Size: Number of changes in transaction
├── Rollback Segment: RBS used for transaction
└── Dependency Info: Other transactions this depends on
```

**COMMIT CDC Significance**:

- **Atomicity Boundary**: All changes become visible together
- **CDC Delivery Point**: When changes are sent to targets
- **Ordering Guarantee**: Commits provide total ordering
- **Consistency Point**: Database consistent after commit

##### **ROLLBACK Operations**

**ROLLBACK Redo Record**:

```
ROLLBACK Redo Record:
├── OpCode: 5.9 (ROLLBACK)
├── Transaction ID: XID being rolled back
├── Rollback SCN: SCN of rollback operation
├── Rollback Reason: User/system initiated
├── Partial Rollback: Savepoint information if applicable
├── Undo Information: References to undo records
└── Cleanup Actions: Resources being released
```

**ROLLBACK CDC Impact**:

- **Change Cancellation**: All transaction changes are undone
- **CDC Filtering**: Rolled back changes should not be delivered
- **Undo Processing**: May generate additional redo for undo
- **Resource Cleanup**: Locks released, space reclaimed

#### **Special Oracle Operations**

##### **MERGE Operations**

```sql
MERGE INTO financial_transactions t
USING (SELECT 'TXN_001' as id, 'COMPLETED' as status FROM dual) s
ON (t.transaction_id = s.id)
WHEN MATCHED THEN
    UPDATE SET status = s.status, updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN
    INSERT (transaction_id, status)
    VALUES (s.id, s.status);
```

**MERGE generates multiple redo records**:

1. **Search Phase**: Redo for row lookups
2. **Match Decision**: Redo for match/no-match determination
3. **Action Execution**: INSERT or UPDATE redo records
4. **Constraint Checking**: Redo for constraint validation

##### **TRUNCATE Operations**

```sql
TRUNCATE TABLE financial_transactions;
```

**TRUNCATE Redo Characteristics**:

- **DDL Operation**: Generates DDL redo record
- **No Row-Level Redo**: Individual row deletes not logged
- **Space Reclamation**: Immediate space release
- **Index Impact**: All indexes truncated simultaneously
- **CDC Challenge**: Mass deletion without individual row records

##### **Partition Operations**

```sql
ALTER TABLE financial_transactions
DROP PARTITION p_2024_q1;
```

**Partition DDL Impact**:

- **Metadata Changes**: Partition definitions updated
- **Data Movement**: Rows may move between partitions
- **Index Maintenance**: Partition indexes affected
- **CDC Complexity**: Partition-aware CDC processing needed

### Supplemental Logging - The CDC Enabler

Supplemental logging is crucial for CDC because standard redo logs contain minimal information optimized for recovery, not change tracking.

#### **Levels of Supplemental Logging**

##### **1. Minimal Supplemental Logging**

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
```

**What it adds**:

- **Row Identification**: Enough information to identify changed rows
- **Primary Key Values**: Always logged for all DML operations
- **Unique Key Values**: Logged when no primary key exists
- **All Column Values**: For tables without primary or unique keys

**Redo Impact**: Minimal overhead, essential for CDC functionality

##### **2. Primary Key Supplemental Logging**

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS;
```

**Enhanced Information**:

- **All Primary Key Columns**: Logged for every DML operation
- **Composite Key Support**: All columns of composite primary keys
- **Key Change Detection**: Before/after values for key changes
- **Referential Integrity**: Support for foreign key relationships

##### **3. Unique Key Supplemental Logging**

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (UNIQUE) COLUMNS;
```

**Additional Coverage**:

- **Unique Constraints**: All unique key columns logged
- **Unique Indexes**: Columns from unique indexes included
- **Alternative Keys**: Support for tables with multiple unique keys
- **Key Hierarchy**: Primary keys take precedence over unique keys

##### **4. All Columns Supplemental Logging**

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```

**Complete Information**:

- **Every Column**: All table columns logged for every DML
- **Unchanged Columns**: Even unmodified columns are logged
- **Complete Row Image**: Full before/after images available
- **Maximum CDC Capability**: Supports all CDC use cases

**Trade-off Analysis**:

```
Logging Level    | Redo Overhead | CDC Capability | Use Case
-----------------|---------------|----------------|------------------
Minimal          | 5-10%         | Basic CDC      | Simple replication
Primary Key      | 10-20%        | Standard CDC   | Most CDC scenarios
Unique Key       | 15-25%        | Enhanced CDC   | Complex key structures
All Columns      | 50-100%       | Complete CDC   | Full audit, analytics
```

##### **5. Table-Level Supplemental Logging**

```sql
-- Granular control per table
ALTER TABLE financial_transactions
ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Specific column groups
ALTER TABLE financial_transactions
ADD SUPPLEMENTAL LOG GROUP grp_audit (
    transaction_id,
    updated_at
) ALWAYS;
```

**Granular Benefits**:

- **Selective Overhead**: Only CDC tables pay logging cost
- **Custom Groups**: Log specific column combinations
- **Performance Optimization**: Minimize redo for non-CDC tables
- **Compliance Focus**: Enhanced logging for audit-critical tables

#### **Supplemental Logging Impact on Redo Records**

**Standard UPDATE Redo (No Supplemental Logging)**:

```
UPDATE financial_transactions
SET status = 'COMPLETED'
WHERE transaction_id = 'TXN_001';

Redo Contains:
├── Changed Column: status ('PENDING' → 'COMPLETED')
├── Row Identifier: ROWID
└── Minimal Key Info: May not include full primary key
```

**UPDATE with All Columns Supplemental Logging**:

```
Same UPDATE statement

Redo Contains:
├── Changed Column: status ('PENDING' → 'COMPLETED')
├── All Other Columns: Complete row before/after images
├── Primary Key: transaction_id = 'TXN_001'
├── All Numeric Fields: amount, processing_time, etc.
├── All Text Fields: description, merchant_id, etc.
└── Null Indicators: For all nullable columns
```

### Oracle Redo Log File Management

#### **Online Redo Log Architecture**

Oracle maintains multiple online redo log groups in a circular fashion:

```
Redo Log Group Structure:
├── Group 1: redo01a.log (Member 1), redo01b.log (Member 2)
├── Group 2: redo02a.log (Member 1), redo02b.log (Member 2)
├── Group 3: redo03a.log (Member 1), redo03b.log (Member 2)
└── Current: Group being written by LGWR
    Active: Groups with uncommitted transactions
    Inactive: Groups available for reuse
```

**Log Switch Process**:

1. **Current Log Full**: LGWR fills current log group
2. **Switch Trigger**: Automatic switch to next group
3. **Checkpoint Signal**: CKPT process notified
4. **Archive Signal**: ARCn process copies log to archive
5. **Reuse Preparation**: Previous log marked inactive after archive

#### **Archive Log Management for CDC**

**Archive Log Naming Convention**:

```sql
-- Set archive format for unique identification
ALTER SYSTEM SET log_archive_format = 'arch_%t_%s_%r.arc' SCOPE=SPFILE;

-- Example archive log names:
-- arch_1_1_1234567890.arc (Thread 1, Sequence 1, Resetlogs ID 1234567890)
-- arch_1_2_1234567890.arc (Thread 1, Sequence 2, Resetlogs ID 1234567890)
```

**Archive Log Retention for CDC**:

```sql
-- Configure retention policy
ALTER SYSTEM SET log_archive_dest_1 =
'LOCATION=/opt/oracle/oradata/XE/archive
 MANDATORY
 REOPEN=300
 MAX_FAILURE=10
 DELAY=0' SCOPE=BOTH;
```

**CDC Archive Log Requirements**:

- **Continuous Availability**: CDC tools need access to all archive logs
- **Retention Period**: Keep logs longer than CDC lag time
- **Storage Planning**: Archive logs can be substantial with supplemental logging
- **Backup Integration**: Archive logs must be backed up for recovery

#### **Log File Size Optimization for CDC**

**Default Oracle XE Configuration**:

```sql
-- Check current redo log configuration
SELECT group#, bytes/1024/1024 as size_mb, members, status
FROM v$log ORDER BY group#;

-- Typical output:
GROUP#  SIZE_MB  MEMBERS  STATUS
------  -------  -------  --------
1       200      1        INACTIVE
2       200      1        CURRENT
3       200      1        INACTIVE
```

**CDC-Optimized Configuration**:

```sql
-- Add smaller redo logs for faster CDC response
ALTER DATABASE ADD LOGFILE GROUP 4 '/opt/oracle/oradata/XE/redo04.log' SIZE 50M;
ALTER DATABASE ADD LOGFILE GROUP 5 '/opt/oracle/oradata/XE/redo05.log' SIZE 50M;
ALTER DATABASE ADD LOGFILE GROUP 6 '/opt/oracle/oradata/XE/redo06.log' SIZE 50M;

-- Drop original large logs (after new logs are active)
ALTER DATABASE DROP LOGFILE GROUP 1;
ALTER DATABASE DROP LOGFILE GROUP 2;
ALTER DATABASE DROP LOGFILE GROUP 3;
```

**Size Impact Analysis**:

```
Scenario: 1MB/hour transaction rate

200MB Logs:
├── Switch Frequency: Every 200 hours (8+ days)
├── CDC Latency: Up to 200 hours for changes
├── Archive Volume: 3 files per 25 days
└── Storage Efficiency: High (fewer files)

50MB Logs:
├── Switch Frequency: Every 50 hours (2+ days)
├── CDC Latency: Up to 50 hours for changes
├── Archive Volume: 12 files per 25 days
└── Storage Efficiency: Lower (more files)

50MB Logs + archive_lag_target=30:
├── Switch Frequency: Every 30 seconds maximum
├── CDC Latency: Maximum 30 seconds
├── Archive Volume: 720 files per day (worst case)
└── Storage Efficiency: Lowest (many small files)
```

### Advanced CDC Optimization Techniques

#### **Log Buffer Tuning**

```sql
-- Check current log buffer size
SELECT name, value FROM v$parameter WHERE name = 'log_buffer';

-- Optimize for CDC workloads
ALTER SYSTEM SET log_buffer = 8388608 SCOPE=SPFILE;  -- 8MB
```

**Log Buffer Impact on CDC**:

- **Larger Buffer**: Reduces LGWR write frequency
- **Batch Efficiency**: More redo entries per I/O operation
- **Reduced Contention**: Less competition for log buffer space
- **CDC Benefit**: Smoother redo generation, more consistent CDC flow

#### **Checkpoint Optimization**

```sql
-- Configure checkpoint frequency
ALTER SYSTEM SET fast_start_mttr_target = 60 SCOPE=BOTH;  -- 60 seconds

-- Monitor checkpoint effectiveness
SELECT * FROM v$instance_recovery;
```

**Checkpoint Impact on CDC**:

- **Faster Recovery**: Shorter instance recovery time
- **SCN Advancement**: More frequent SCN progression
- **Redo Availability**: Older redo logs archived sooner
- **CDC Consistency**: Better consistency points for CDC tools

#### **Archive Process Optimization**

```sql
-- Configure multiple archive processes for high volume
ALTER SYSTEM SET log_archive_max_processes = 4 SCOPE=BOTH;

-- Monitor archive process performance
SELECT process, status, sequence# FROM v$managed_standby
WHERE process LIKE 'ARC%';
```

**Multi-Process Archiving Benefits**:

- **Parallel Processing**: Multiple logs archived simultaneously
- **Reduced Lag**: Faster archive log availability for CDC
- **Higher Throughput**: Better handling of log switch bursts
- **Fault Tolerance**: Backup processes if primary fails

### CDC Performance Monitoring and Optimization

#### **Key Performance Indicators for Oracle CDC**

##### **1. Log Switch Frequency**

```sql
-- Monitor log switch patterns
SELECT
    TO_CHAR(first_time, 'YYYY-MM-DD HH24') as hour,
    COUNT(*) as switches,
    AVG(bytes)/1024/1024 as avg_size_mb
FROM v$log_history
WHERE first_time > SYSDATE - 7
GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY hour DESC;
```

**Optimal Patterns**:

- **Consistent Frequency**: Regular switches indicate steady workload
- **Size Consistency**: Similar sizes suggest predictable redo generation
- **No Gaps**: Continuous switches ensure CDC data availability

##### **2. Archive Lag Monitoring**

```sql
-- Check archive lag target effectiveness
SELECT
    name,
    value,
    CASE
        WHEN name = 'archive_lag_target' AND value > 0
        THEN 'Time-based switching enabled'
        ELSE 'Size-based switching only'
    END as switch_mode
FROM v$parameter
WHERE name IN ('archive_lag_target', 'log_archive_dest_1');

-- Monitor actual archive lag
SELECT
    sequence#,
    first_time,
    next_time,
    (next_time - first_time) * 24 * 60 as duration_minutes
FROM v$log_history
WHERE first_time > SYSDATE - 1
ORDER BY sequence# DESC;
```

##### **3. Redo Generation Rate**

```sql
-- Monitor redo generation statistics
SELECT
    name,
    value,
    ROUND(value/1024/1024, 2) as value_mb
FROM v$sysstat
WHERE name IN (
    'redo size',
    'redo entries',
    'redo writes',
    'redo blocks written'
)
ORDER BY name;

-- Calculate redo rate over time
SELECT
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI') as time_period,
    ROUND(value/1024/1024, 2) as redo_mb_per_minute
FROM v$sysmetric_history
WHERE metric_name = 'Redo Generated Per Sec'
AND end_time > SYSDATE - 1/24  -- Last hour
ORDER BY end_time DESC;
```

##### **4. Supplemental Logging Overhead**

```sql
-- Measure supplemental logging impact
SELECT
    s1.name as metric,
    s1.value as current_value,
    s2.value as baseline_value,
    ROUND(((s1.value - s2.value) / s2.value) * 100, 2) as percent_increase
FROM v$sysstat s1, v$sysstat s2
WHERE s1.name = s2.name
AND s1.name IN ('redo size', 'redo entries')
-- Compare current vs baseline (requires baseline capture)
```

#### **CDC-Specific Oracle Tuning Parameters**

```sql
-- Comprehensive CDC optimization parameter set
ALTER SYSTEM SET log_buffer = 8388608 SCOPE=SPFILE;                    -- 8MB log buffer
ALTER SYSTEM SET log_checkpoint_interval = 0 SCOPE=BOTH;               -- Disable interval checkpoints
ALTER SYSTEM SET log_checkpoint_timeout = 1800 SCOPE=BOTH;             -- 30-minute timeout checkpoints
ALTER SYSTEM SET archive_lag_target = 30 SCOPE=BOTH;                   -- 30-second max lag
ALTER SYSTEM SET log_archive_max_processes = 4 SCOPE=BOTH;             -- 4 archive processes
ALTER SYSTEM SET commit_write = 'BATCH,NOWAIT' SCOPE=BOTH;             -- Async commit for performance
ALTER SYSTEM SET disk_asynch_io = TRUE SCOPE=SPFILE;                   -- Async I/O for redo
ALTER SYSTEM SET filesystemio_options = 'SETALL' SCOPE=SPFILE;         -- All I/O optimizations
```

**Parameter Justification**:

- **log_buffer**: Larger buffer reduces LGWR frequency
- **`log_checkpoint_*`**: Optimizes checkpoint timing for CDC
- **archive_lag_target**: Guarantees CDC data availability
- **log_archive_max_processes**: Parallel archiving for high volume
- **commit_write**: Faster commits improve CDC throughput
- **disk_asynch_io**: Async I/O reduces redo write latency
- **filesystemio_options**: Enables all I/O optimizations

This comprehensive analysis provides the deep technical foundation needed to understand how Oracle logging works and why specific optimizations are crucial for effective Change Data Capture in the Iceberg Data Lakehouse architecture.

### Table Mapping Configuration

DMS uses table mapping rules to determine which tables to replicate:

```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-oracle-user-tables",
      "object-locator": {
        "schema-name": "ORACLE_USER",
        "table-name": "%"
      },
      "rule-action": "include"
    }
  ]
}
```

### CDC Monitoring and Troubleshooting

#### Key Oracle Views for CDC Monitoring:

1. **Check Archive Log Status**:

```sql
SELECT dest_id, status, destination FROM v$archive_dest WHERE dest_id = 1;
```

2. **Monitor Redo Log Activity**:

```sql
SELECT group#, sequence#, bytes/1024/1024 as size_mb, status, archived
FROM v$log ORDER BY group#;
```

3. **Verify Supplemental Logging**:

```sql
SELECT supplemental_log_data_min, supplemental_log_data_pk, supplemental_log_data_all
FROM v$database;
```

4. **Check LogMiner Contents** (for verification):

```sql
SELECT scn, timestamp, operation, seg_owner, table_name
FROM v$logmnr_contents
WHERE seg_owner = 'ORACLE_USER'
AND operation IN ('INSERT', 'UPDATE', 'DELETE')
ORDER BY timestamp DESC;
```

#### Common CDC Issues and Solutions:

1. **"No tables found"**:

   - Check schema name case sensitivity (must be ORACLE_USER uppercase)
   - Verify supplemental logging is enabled
   - Ensure tables have primary keys

2. **"ARCHIVELOG mode not configured"**:

   - Enable ARCHIVELOG mode
   - Configure archive log destination

3. **"Cannot retrieve archived redo log destination"**:

   - Set proper archive log destination
   - Ensure DMS has file system access

4. **High CDC Latency**:
   - Implement smaller redo logs (50MB)
   - Set archive_lag_target to 30 seconds
   - Optimize log buffer settings

### Helper Scripts

#### sqlapp Alias (Generated by user_data.sh)

The script creates a convenient alias for connecting to Oracle as the application user:

```bash
alias sqlapp='sqlplus $APP_DB_USER/"$APP_DB_PASSWORD"@$APP_DB_HOST:$APP_DB_PORT/$APP_DB_SERVICE'
```

This provides easy access to:

- Query application tables
- Verify data integrity
- Test CDC functionality
- Monitor table changes

#### sqlsys Alias (Generated by user_data.sh)

For administrative tasks:

```bash
alias sqlsys='sqlplus / as sysdba'
```

Used for:

- CDC configuration verification
- Archive log monitoring
- Supplemental logging management
- Performance tuning

## Usage

### Automatic Deployment

The `user_data.sh` script is used as a template file in the EC2 instance resource:

```hcl
user_data_base64 = base64gzip(templatefile("${path.module}/scripts/user_data.sh", {
  ORACLE_SID = var.ORACLE_SID,
  ORACLE_PDB = var.ORACLE_PDB,
  ORACLE_USER = var.ORACLE_USER,
  ORACLE_PORT = var.ORACLE_PORT,
  ORACLE_VERSION = var.ORACLE_VERSION,
  AWS_REGION = data.aws_region.current.id,
  ORACLE_CDC_PASSWORD_SECRET_ARN = aws_secretsmanager_secret.oracle_cdc_password.arn,
  ORACLE_USER_PASSWORD_SECRET_ARN = aws_secretsmanager_secret.oracle_user_password.arn
}))
```

### DMS Integration Workflow

1. **Oracle Deployment**: EC2 instance launches with CDC-optimized Oracle configuration
2. **DMS Endpoint Creation**: DMS source endpoint configured for Binary File Reader
3. **DMS Task Creation**: Replication task created with table mappings
4. **CDC Initialization**: DMS establishes baseline and starts monitoring changes
5. **Real-time Replication**: Changes flow from Oracle → DMS → MSK/Kafka

### Testing CDC Functionality

After deployment, test CDC functionality:

```bash
# Connect to Oracle instance
aws ssm start-session --target <instance-id>

# Switch to oracle user
sudo su - oracle

# Connect to database
sqlapp

# Insert test data
INSERT INTO FINANCIAL_TRANSACTIONS (TRANSACTION_ID, TRANSACTION_TYPE, TRANSACTION_AMOUNT)
VALUES ('CDC_TEST_' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS'), 'TEST', 100.00);
COMMIT;

# Force log switch for immediate CDC availability
sqlsys
ALTER SYSTEM SWITCH LOGFILE;
```

## Dependencies

### System Requirements

- Amazon Linux 2 or 2023
- Minimum 4GB RAM for Oracle XE
- 50GB+ EBS volume for Oracle data
- Internet access for package downloads

### AWS Permissions

The EC2 instance requires IAM permissions for:

- **Secrets Manager**: Read Oracle passwords
- **KMS**: Decrypt secrets
- **SSM**: Store connection parameters
- **CloudWatch**: Send logs and metrics

### Network Requirements

- **Inbound**: Port 1521 for Oracle connections (from DMS subnet)
- **Outbound**: HTTPS (443) for AWS API calls
- **Security Groups**: Properly configured for DMS access

## Troubleshooting

### Oracle CDC Issues

1. **Check Oracle CDC Configuration**:

```sql
-- Verify ARCHIVELOG mode
SELECT log_mode FROM v$database;

-- Check supplemental logging
SELECT supplemental_log_data_min, supplemental_log_data_pk, supplemental_log_data_all FROM v$database;

-- Verify archive destination
SELECT dest_id, status, destination FROM v$archive_dest WHERE dest_id = 1;
```

2. **Monitor Redo Log Activity**:

```sql
-- Check current redo log status
SELECT group#, sequence#, bytes/1024/1024 as size_mb, status FROM v$log ORDER BY group#;

-- Check archive lag target
SELECT value FROM v$parameter WHERE name = 'archive_lag_target';
```

3. **Test LogMiner Functionality**:

```sql
-- Add current log to LogMiner
EXEC DBMS_LOGMNR.ADD_LOGFILE(LOGFILENAME => '/opt/oracle/oradata/XE/redo01.log', OPTIONS => DBMS_LOGMNR.NEW);

-- Start LogMiner
EXEC DBMS_LOGMNR.START_LOGMNR(OPTIONS => DBMS_LOGMNR.DICT_FROM_ONLINE_CATALOG);

-- Check for recent changes
SELECT scn, timestamp, operation, seg_owner, table_name
FROM v$logmnr_contents
WHERE seg_owner = 'ORACLE_USER'
AND timestamp > SYSDATE - 1/24;

-- Stop LogMiner
EXEC DBMS_LOGMNR.END_LOGMNR();
```

### DMS Troubleshooting

1. **Check DMS Task Status**:

```bash
aws dms describe-replication-tasks --region us-east-1 --query 'ReplicationTasks[?contains(ReplicationTaskIdentifier, `oracle-to-msk`)].{Status:Status,LastFailureMessage:LastFailureMessage}'
```

2. **Monitor DMS Logs**:

```bash
aws logs describe-log-groups --log-group-name-prefix "dms-tasks" --region us-east-1
aws logs get-log-events --log-group-name "dms-tasks-oracle-to-msk" --log-stream-name "dms-task-stream" --region us-east-1
```

3. **Test Endpoint Connectivity**:

```bash
aws dms test-connection --replication-instance-arn <instance-arn> --endpoint-arn <oracle-endpoint-arn> --region us-east-1
```

### Common Error Solutions

| Error                               | Cause                              | Solution                                         |
| ----------------------------------- | ---------------------------------- | ------------------------------------------------ |
| "No tables found"                   | Schema name case mismatch          | Use `ORACLE_USER` (uppercase) in table mappings  |
| "ARCHIVELOG not configured"         | Database not in ARCHIVELOG mode    | Run ARCHIVELOG enablement script                 |
| "Cannot retrieve archived redo log" | Archive destination not configured | Set `log_archive_dest_1` parameter               |
| "Endpoint initialization failed"    | File permissions or path issues    | Verify redo log file permissions and paths       |
| High CDC latency                    | Large redo logs                    | Implement 50MB redo logs with archive_lag_target |

### Log File Locations

- **User Data Logs**: `/var/log/user-data.log`
- **Cloud Init Logs**: `/var/log/cloud-init-output.log`
- **Oracle Alert Logs**: `/opt/oracle/diag/rdbms/xe/XE/trace/alert_XE.log`
- **Oracle Listener Logs**: `/opt/oracle/diag/tnslsnr/*/listener/trace/listener.log`
- **Archive Logs**: `/opt/oracle/oradata/XE/archive/`

## Manual Operations

### Connecting to Oracle

The user data script creates convenient aliases for database access:

```bash
# Connect via SSM Session Manager
aws ssm start-session --target <instance-id>

# Switch to oracle user (loads environment and aliases)
sudo su - oracle

# Connect as application user
sqlapp

# Connect as SYSDBA for administrative tasks
sqlsys
```

### Manual CDC Configuration

If you need to manually configure CDC settings:

```bash
# Connect as SYSDBA
sqlsys

# Enable ARCHIVELOG mode
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

# Configure archive destination
ALTER SYSTEM SET log_archive_dest_1='LOCATION=/opt/oracle/oradata/XE/archive' SCOPE=BOTH;

# Enable supplemental logging
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

# Add smaller redo logs for better CDC performance
ALTER DATABASE ADD LOGFILE GROUP 4 '/opt/oracle/oradata/XE/redo04.log' SIZE 50M;
ALTER DATABASE ADD LOGFILE GROUP 5 '/opt/oracle/oradata/XE/redo05.log' SIZE 50M;
ALTER DATABASE ADD LOGFILE GROUP 6 '/opt/oracle/oradata/XE/redo06.log' SIZE 50M;

# Configure automatic log switching
ALTER SYSTEM SET archive_lag_target = 30 SCOPE=BOTH;
```

### Checking Oracle CDC Status

Monitor CDC-related Oracle settings:

```bash
# Check Oracle service status
sudo systemctl status oracle-xe-21c

# Check Oracle listener status
sudo su - oracle -c "lsnrctl status"

# Verify CDC configuration
sqlsys
SELECT log_mode FROM v$database;
SELECT supplemental_log_data_min FROM v$database;
SELECT dest_id, status, destination FROM v$archive_dest WHERE dest_id = 1;
SELECT group#, bytes/1024/1024 as size_mb, status FROM v$log ORDER BY group#;
```

### Force Log Switch for Testing

To make changes immediately available to DMS:

```bash
sqlsys
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

## Performance Optimization

### CDC Latency Optimization

The script implements several optimizations for low-latency CDC:

1. **Smaller Redo Logs**: 50MB logs vs default 200MB
2. **Automatic Log Switching**: Every 30 seconds maximum
3. **Optimized Log Buffer**: 8MB for faster writes
4. **Fast Checkpoints**: 60-second recovery target

### Monitoring CDC Performance

```sql
-- Check archive lag target effectiveness
SELECT name, value FROM v$parameter WHERE name = 'archive_lag_target';

-- Monitor log switch frequency
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24:MI:SS') as switch_time, sequence#
FROM v$log_history
WHERE first_time > SYSDATE - 1/24  -- Last 24 hours
ORDER BY first_time DESC;

-- Check redo generation rate
SELECT name, value FROM v$sysstat WHERE name LIKE '%redo%' AND value > 0;
```

## Integration with Data Lakehouse

This Oracle CDC configuration integrates with the broader Iceberg Data Lakehouse architecture:

1. **Source**: Oracle database with optimized CDC configuration
2. **Ingestion**: AWS DMS captures changes using Binary File Reader
3. **Streaming**: Changes flow to Amazon MSK (Kafka)
4. **Processing**: Kinesis Data Firehose processes and formats data
5. **Storage**: Data stored in S3 using Apache Iceberg format
6. **Analytics**: Available through Athena and Snowflake

The CDC optimization ensures that data changes are available in the lakehouse within minutes of occurring in the source Oracle database, enabling near real-time analytics and reporting.
