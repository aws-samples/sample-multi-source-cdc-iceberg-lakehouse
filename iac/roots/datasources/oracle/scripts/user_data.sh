#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
# Clean Oracle XE Installation Script for Data Generator - OPTIMIZED VERSION

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "========================================================================"
echo "                   ORACLE XE INSTALLATION SCRIPT                       "
echo "========================================================================"
echo "Starting Oracle installation at $(date)"

# Set environment variables
ORACLE_SID="${ORACLE_SID}"
ORACLE_PDB="${ORACLE_PDB}"
ORACLE_USER="${ORACLE_USER}"
ORACLE_PORT="${ORACLE_PORT}"
ORACLE_VERSION="${ORACLE_VERSION}"
AWS_REGION="${AWS_REGION}"
ORACLE_CDC_PASSWORD_SECRET_ARN="${ORACLE_CDC_PASSWORD_SECRET_ARN}"
ORACLE_USER_PASSWORD_SECRET_ARN="${ORACLE_USER_PASSWORD_SECRET_ARN}"

echo "Configuration: SID=$ORACLE_SID, PORT=$ORACLE_PORT, USER=$ORACLE_USER"

#==============================================================================
# FUNCTION: Get passwords from Secrets Manager
#==============================================================================
get_passwords() {
    echo "Retrieving passwords from Secrets Manager..."
    
    ORACLE_PASSWORD=$(aws secretsmanager get-secret-value \
        --secret-id $ORACLE_CDC_PASSWORD_SECRET_ARN \
        --region $AWS_REGION \
        --query SecretString --output text)
    
    ORACLE_USER_PASSWORD=$(aws secretsmanager get-secret-value \
        --secret-id $ORACLE_USER_PASSWORD_SECRET_ARN \
        --region $AWS_REGION \
        --query SecretString --output text)
    
    if [ -z "$ORACLE_PASSWORD" ] || [ -z "$ORACLE_USER_PASSWORD" ]; then
        echo "ERROR: Failed to retrieve passwords"
        exit 1
    fi
    
    echo "✓ Passwords retrieved successfully"
}

#==============================================================================
# FUNCTION: Setup EBS volume
#==============================================================================
setup_ebs_volume() {
    echo "Setting up EBS volume..."
    EBS_DEVICE="/dev/sdb"
    EBS_MOUNT_POINT="/opt/oracle"
    
    while [ ! -e $EBS_DEVICE ]; do
        echo "Waiting for EBS volume..."
        sleep 5
    done
    
    if ! blkid $EBS_DEVICE; then
        mkfs.ext4 -F $EBS_DEVICE
    fi
    
    mkdir -p $EBS_MOUNT_POINT
    mount $EBS_DEVICE $EBS_MOUNT_POINT
    
    UUID=$(blkid -s UUID -o value $EBS_DEVICE)
    echo "UUID=$UUID /opt/oracle ext4 defaults,nofail 0 2" >> /etc/fstab
    
    echo "✓ EBS volume mounted at /opt/oracle"
}

#==============================================================================
# FUNCTION: Install required packages
#==============================================================================
install_packages() {
    echo "Installing required packages..."
    
    # Wait for yum lock
    WAIT_COUNT=0
    while fuser /var/lib/rpm/.rpm.lock >/dev/null 2>&1 && [ $WAIT_COUNT -lt 300 ]; do
        sleep 10
        WAIT_COUNT=$((WAIT_COUNT + 10))
    done
    
    yum clean all
    yum install -y wget expect bc unzip
    
    echo "✓ Required packages installed"
}

#==============================================================================
# FUNCTION: Detect and set Oracle home (CONSOLIDATED)
#==============================================================================
detect_oracle_home() {
    if [ -n "$ORACLE_HOME" ] && [ -d "$ORACLE_HOME" ]; then
        return 0  # Already set and valid
    fi
    
    if [ -d "/opt/oracle/product/${ORACLE_VERSION}/dbhomeXE" ]; then
        export ORACLE_HOME="/opt/oracle/product/${ORACLE_VERSION}/dbhomeXE"
    elif [ -d "/opt/oracle/product/${ORACLE_VERSION}/dbhome${ORACLE_SID}" ]; then
        export ORACLE_HOME="/opt/oracle/product/${ORACLE_VERSION}/dbhome${ORACLE_SID}"
    else
        echo "ERROR: Could not find Oracle home directory"
        exit 1
    fi
    
    echo "✓ Oracle home detected: $ORACLE_HOME"
}

#==============================================================================
# FUNCTION: Set Oracle environment variables (CONSOLIDATED)
#==============================================================================
set_oracle_environment() {
    detect_oracle_home
    export ORACLE_SID="${ORACLE_SID}"
    export ORACLE_BASE="/opt/oracle"
    export PATH="$PATH:$ORACLE_HOME/bin"
    export LD_LIBRARY_PATH="$ORACLE_HOME/lib:$LD_LIBRARY_PATH"
    export NLS_LANG="AMERICAN_AMERICA.AL32UTF8"
    export TNS_ADMIN="$ORACLE_HOME/network/admin"
}

#==============================================================================
# FUNCTION: Download and install Oracle XE
#==============================================================================
install_oracle() {
    echo "Downloading and installing Oracle ${ORACLE_SID}..."
    
    # Download Oracle packages
    wget -q https://download.oracle.com/otn-pub/otn_software/db-express/oracle-database-xe-${ORACLE_VERSION}-1.0-1.ol8.x86_64.rpm &
    wget -q https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/getPackage/oracle-database-preinstall-${ORACLE_VERSION}-1.0-1.el8.x86_64.rpm &
    wget -q https://dl.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/Packages/c/compat-openssl10-1.0.2o-4.el8_10.1.x86_64.rpm -O compat-openssl10.rpm &
    wait

    # Verify the compat-openssl10 RPM by SHA-256; fail installation if tampered.
    echo "1bcfd225008cff6370acade7b6bbcaad1b8b35e854744747eb3bbab0a5b8c13a  compat-openssl10.rpm" | sha256sum -c - || {
        echo "ERROR: compat-openssl10.rpm SHA-256 mismatch - aborting install" >&2
        exit 1
    }
    
    # Install packages
    rpm -ivh --nodeps compat-openssl10.rpm
    rpm -ivh --nodeps oracle-database-preinstall-${ORACLE_VERSION}-1.0-1.el8.x86_64.rpm
    
    # Create oracle user if needed
    if ! getent passwd oracle > /dev/null 2>&1; then
        useradd -u 54321 -g oinstall -m -s /bin/bash oracle
    fi
    
    # Create Oracle directories
    mkdir -p /opt/oracle/{oradata,oraInventory,app/oracle/{oradata/${ORACLE_SID},fast_recovery_area,audit}}
    mkdir -p /var/opt/oracle /home/oracle
    chown -R oracle:oinstall /opt/oracle /var/opt/oracle /home/oracle
    chmod -R 755 /opt/oracle /var/opt/oracle /home/oracle
    
    # Install Oracle XE
    rpm -ivh --nodeps oracle-database-xe-${ORACLE_VERSION}-1.0-1.ol8.x86_64.rpm
    
    # Detect actual Oracle home after installation
    detect_oracle_home

    echo "✓ Oracle ${ORACLE_SID} installed at $ORACLE_HOME"
}

#==============================================================================
# FUNCTION: Configure Oracle XE
#==============================================================================
configure_oracle() {
    echo "Configuring Oracle XE..."
    
    # Create configuration file
    cat > /etc/sysconfig/oracle-xe-${ORACLE_VERSION}.conf << EOF
LISTENER_PORT=$ORACLE_PORT
EM_EXPRESS_PORT=5500
CHARSET=AL32UTF8
DBFILE_DEST=/opt/oracle/oradata
ORACLE_PASSWORD="$ORACLE_PASSWORD"
EOF
    
    # Configure using expect
    cat > /tmp/oracle_configure.exp << EOF
#!/usr/bin/expect -f
set timeout 7200
set password [lindex $argv 0]
log_user 0
spawn /etc/init.d/oracle-xe-${ORACLE_VERSION} configure
expect {
    "Enter SYS user password:" {
        send "$password\r"
        exp_continue
    }
    "Enter SYSTEM user password:" {
        send "$password\r"
        exp_continue
    }
    "Enter PDBADMIN User Password:" {
        send "$password\r"
        exp_continue
    }
    "Database configuration completed successfully" {
        puts "Oracle configuration completed"
    }
    timeout {
        puts "Configuration timed out"
        exit 1
    }
    eof
}
EOF
    
    chmod +x /tmp/oracle_configure.exp
    expect /tmp/oracle_configure.exp "$ORACLE_PASSWORD"

    # Readiness gate — verify DBCA completed and database is accessible
    set_oracle_environment
    echo "Verifying Oracle database is ready..."
    for i in {1..60}; do
        if su - oracle -c "export ORACLE_HOME=$ORACLE_HOME ORACLE_SID=$ORACLE_SID; $ORACLE_HOME/bin/sqlplus -s / as sysdba <<< 'SELECT 1 FROM DUAL;'" 2>/dev/null | grep -q "1"; then
            echo "✓ Oracle database is ready"
            break
        fi
        if [ $i -eq 60 ]; then
            echo "ERROR: Oracle database not ready after 10 minutes"
            exit 1
        fi
        echo "  Attempt $i/60 — waiting 10s..."
        sleep 10
    done

    echo "✓ Oracle ${ORACLE_SID} configured"
}

#==============================================================================
# FUNCTION: Setup Oracle environment and service
#==============================================================================
setup_oracle_service() {
    echo "Setting up Oracle service..."
    
    # Set Oracle environment
    set_oracle_environment

    # Set system-wide environment variables
    cat > /etc/profile.d/oracle-xe-${ORACLE_VERSION}.sh << EOF
export ORACLE_HOME=$ORACLE_HOME
export ORACLE_SID=${ORACLE_SID}
export ORACLE_BASE=/opt/oracle
export PATH=\$PATH:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export TNS_ADMIN=$ORACLE_HOME/network/admin
EOF
    
    source /etc/profile.d/oracle-xe-${ORACLE_VERSION}.sh
    
    # Setup oracle user environment
    USER_PWD=$(echo "$ORACLE_USER_PASSWORD" | cut -c1-30)
    su - oracle -c "cat >> ~/.bash_profile << EOF
export ORACLE_HOME=$ORACLE_HOME
export ORACLE_SID=${ORACLE_SID}
export ORACLE_BASE=/opt/oracle
export PATH=\$PATH:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export TNS_ADMIN=$ORACLE_HOME/network/admin

# Application user connection details
export APP_DB_USER=${ORACLE_USER}
export APP_DB_PASSWORD='$${USER_PWD}'
export APP_DB_HOST=localhost
export APP_DB_PORT=${ORACLE_PORT}
export APP_DB_SERVICE=${ORACLE_PDB}
alias sqlapp='sqlplus ${ORACLE_USER}/\"$${USER_PWD}\"@localhost:${ORACLE_PORT}/${ORACLE_PDB}'
alias sqlsys='sqlplus / as sysdba'

export APP_CONNECTION_STRING=${ORACLE_USER}/\"$${USER_PWD}\"@localhost:${ORACLE_PORT}/${ORACLE_PDB}
EOF"
    
    # Create systemd service
    cat > /etc/systemd/system/oracle-xe-${ORACLE_VERSION}.service << EOF
[Unit]
Description=Oracle Database ${ORACLE_VERSION} Express Edition
After=network.target

[Service]
Type=forking
RemainAfterExit=yes
ExecStart=$ORACLE_HOME/bin/dbstart $ORACLE_HOME
ExecStop=$ORACLE_HOME/bin/dbshut $ORACLE_HOME
User=oracle
Group=oinstall

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable oracle-xe-${ORACLE_VERSION}
    
    echo "✓ Oracle service configured"
}

#==============================================================================
# FUNCTION: Configure Oracle listener to bind to 0.0.0.0
#==============================================================================
configure_listener() {
    echo "Configuring Oracle listener to bind to 0.0.0.0..."

    # Set Oracle environment
    set_oracle_environment

    # Ensure network/admin directory exists
    su - oracle -c "mkdir -p \$ORACLE_HOME/network/admin"

    # Stop the listener (ignore errors if not running)
    su - oracle -c 'lsnrctl stop' || true

    # Backup original listener.ora if it exists
    su - oracle -c 'if [ -f $ORACLE_HOME/network/admin/listener.ora ]; then cp $ORACLE_HOME/network/admin/listener.ora $ORACLE_HOME/network/admin/listener.ora.backup; fi'

    # Create new listener.ora that binds to 0.0.0.0
    su - oracle -c "cat > $ORACLE_HOME/network/admin/listener.ora << EOF
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = ${ORACLE_PORT}))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

DEFAULT_SERVICE_LISTENER = ${ORACLE_SID}
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (SID_NAME = ${ORACLE_SID})
      (ORACLE_HOME = $ORACLE_HOME)
    )
  )

INBOUND_CONNECT_TIMEOUT_LISTENER = 60
SQLNET.INBOUND_CONNECT_TIMEOUT = 60
EOF"

    # Start the listener
    su - oracle -c 'lsnrctl start'

    # Wait for listener to start
    sleep 10

    # Update the database to use the new listener configuration
    su - oracle -c "$ORACLE_HOME/bin/sqlplus -s / as sysdba << 'EOSQL'
-- Set the local listener parameter to match our new configuration
ALTER SYSTEM SET LOCAL_LISTENER='(ADDRESS=(PROTOCOL=TCP)(HOST=0.0.0.0)(PORT=${ORACLE_PORT}))' SCOPE=BOTH;

-- Force service registration
ALTER SYSTEM REGISTER;

EXIT;
EOSQL"

    echo "✓ Oracle listener configured to bind to 0.0.0.0"
}

#==============================================================================
# FUNCTION: Start Oracle and configure for data generator
#==============================================================================
start_and_configure_oracle() {
    echo "Starting Oracle and configuring for data generator..."
    
    # Set Oracle environment
    set_oracle_environment
    
    # Start Oracle service
    systemctl start oracle-xe-${ORACLE_VERSION}
    
    # Wait for Oracle to start
    sleep 30
    
    # Configure Oracle for proper service registration
    su - oracle -c '$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF
-- Open all PDBs
ALTER PLUGGABLE DATABASE ALL OPEN;

-- Set critical parameters for service registration
ALTER SYSTEM SET LOCAL_LISTENER="(ADDRESS=(PROTOCOL=TCP)(HOST=0.0.0.0)(PORT=1521))" SCOPE=BOTH;
ALTER SYSTEM SET SERVICE_NAMES="${ORACLE_SID},${ORACLE_PDB}" SCOPE=BOTH;

-- Force service registration
ALTER SYSTEM REGISTER;

EXIT;
EOF'
    
    # Restart listener for clean registration
    su - oracle -c 'lsnrctl stop; sleep 3; lsnrctl start'
    
    # Force registration again
    sleep 10
    su - oracle -c '$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF
ALTER SYSTEM REGISTER;
EXIT;
EOF'
    
    echo "✓ Oracle started and services registered"
}

#==============================================================================
# FUNCTION: Create Oracle user
#==============================================================================
create_oracle_user() {
    echo "Creating ${ORACLE_USER} user..."
    
    # Truncate password if too long (Oracle 30 char limit)
    USER_PWD=$(echo "$ORACLE_USER_PASSWORD" | cut -c1-30)
    
    # Create SQL script with proper escaping
    cat > /tmp/create_user.sql << EOF
-- Disable variable substitution to handle special characters in passwords
SET DEFINE OFF;

-- Switch to PDB
ALTER SESSION SET CONTAINER = ${ORACLE_PDB};

-- Drop user if exists
BEGIN
    EXECUTE IMMEDIATE 'DROP USER ${ORACLE_USER} CASCADE';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- Create user with password
CREATE USER ${ORACLE_USER} IDENTIFIED BY "$USER_PWD";
GRANT CONNECT, RESOURCE, CREATE TABLE, CREATE SEQUENCE TO ${ORACLE_USER};
GRANT UNLIMITED TABLESPACE TO ${ORACLE_USER};

EXIT;
EOF

    # Execute the SQL script
    su - oracle -c "$ORACLE_HOME/bin/sqlplus -s / as sysdba @/tmp/create_user.sql"

    # Clean up
    rm -f /tmp/create_user.sql
    
    echo "✓ Oracle user created"
}

#==============================================================================
# FUNCTION: Configure Oracle for CDC
#==============================================================================
configure_oracle_for_cdc() {
    echo "Configuring Oracle for CDC..."

    # Set Oracle environment
    set_oracle_environment

    # Create CDC configuration script
    cat > /tmp/configure_cdc.sql << EOF
-- Connect as sysdba
CONNECT / AS SYSDBA

-- Disable variable substitution to prevent prompts
SET DEFINE OFF;

-- ============================================================================
-- STEP 1: Configure Archive Log Mode (Required for CDC)
-- ============================================================================
SELECT 'Current archive log mode: ' || log_mode FROM v\$database;

-- Enable archivelog mode if not already enabled
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

SELECT 'Archive log mode after configuration: ' || log_mode FROM v\$database;

-- ============================================================================
-- STEP 2: Enable Supplemental Logging (DATABASE LEVEL - COVERS ALL TABLES)
-- ============================================================================
-- This single configuration covers ALL tables in the database
-- No need for table-specific supplemental logging
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Verify supplemental logging is enabled
SELECT 'Supplemental logging (MIN): ' || supplemental_log_data_min FROM v\$database;
SELECT 'Supplemental logging (ALL): ' || supplemental_log_data_all FROM v\$database;

-- ============================================================================
-- STEP 3: Configure Archive Log Destination and Parameters
-- ============================================================================
!mkdir -p /opt/oracle/oradata/${ORACLE_SID}/archive
!chown oracle:oinstall /opt/oracle/oradata/${ORACLE_SID}/archive
ALTER SYSTEM SET log_archive_dest_1='LOCATION=/opt/oracle/oradata/${ORACLE_SID}/archive' SCOPE=BOTH;
ALTER SYSTEM SET log_archive_format='arch_%t_%s_%r.arc' SCOPE=SPFILE;
ALTER SYSTEM SET log_archive_start=TRUE SCOPE=SPFILE;

-- ============================================================================
-- STEP 4: Optimize Redo Log Configuration for CDC Performance
-- ============================================================================
SELECT 'Current redo log configuration:' FROM dual;
SELECT group#, bytes/1024/1024 as size_mb, members, status FROM v\$log ORDER BY group#;

-- Add redo log groups sized for dual CDC readers (Debezium + DMS)
ALTER DATABASE ADD LOGFILE GROUP 4 '/opt/oracle/oradata/${ORACLE_SID}/redo04.log' SIZE 200M;
ALTER DATABASE ADD LOGFILE GROUP 5 '/opt/oracle/oradata/${ORACLE_SID}/redo05.log' SIZE 200M;
ALTER DATABASE ADD LOGFILE GROUP 6 '/opt/oracle/oradata/${ORACLE_SID}/redo06.log' SIZE 200M;

-- Switch to activate new log groups
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;

-- Configure automatic log switching every 30 seconds
ALTER SYSTEM SET archive_lag_target = 30 SCOPE=BOTH;

-- Configure checkpoint frequency for better CDC performance
ALTER SYSTEM SET fast_start_mttr_target = 60 SCOPE=BOTH;

-- ============================================================================
-- STEP 5: Create CDC Service Accounts
-- ============================================================================

-- 5a: C##DBZUSER — CDB common user for Debezium LogMiner
-- LogMiner reads redo logs at CDB level; user must be a common user (C## prefix)
-- with CONTAINER=ALL grants.
ALTER SESSION SET CONTAINER = CDB\$ROOT;

DECLARE
    user_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO user_exists FROM cdb_users WHERE username = 'C##DBZUSER';
    IF user_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP USER C##DBZUSER CASCADE';
    END IF;
END;
/

CREATE USER C##DBZUSER IDENTIFIED BY "$ORACLE_PASSWORD"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 50M ON USERS
    CONTAINER=ALL;

-- Core session and LogMiner privileges
GRANT CREATE SESSION TO C##DBZUSER CONTAINER=ALL;
GRANT SET CONTAINER TO C##DBZUSER CONTAINER=ALL;
GRANT LOGMINING TO C##DBZUSER CONTAINER=ALL;
GRANT CREATE TABLE TO C##DBZUSER CONTAINER=ALL;
GRANT CREATE SEQUENCE TO C##DBZUSER CONTAINER=ALL;
GRANT UNLIMITED TABLESPACE TO C##DBZUSER CONTAINER=ALL;

-- Snapshot and dictionary privileges
GRANT SELECT ANY TABLE TO C##DBZUSER CONTAINER=ALL;
GRANT FLASHBACK ANY TABLE TO C##DBZUSER CONTAINER=ALL;
GRANT LOCK ANY TABLE TO C##DBZUSER CONTAINER=ALL;
GRANT SELECT ANY DICTIONARY TO C##DBZUSER CONTAINER=ALL;

-- Explicit EXECUTE on LogMiner packages (LOGMINING privilege alone is insufficient)
GRANT EXECUTE ON SYS.DBMS_LOGMNR TO C##DBZUSER CONTAINER=ALL;
GRANT EXECUTE ON SYS.DBMS_LOGMNR_D TO C##DBZUSER CONTAINER=ALL;

-- DBMS_METADATA for table DDL lookup during snapshot (Debezium 2.x requirement)
GRANT EXECUTE ON SYS.DBMS_METADATA TO C##DBZUSER CONTAINER=ALL;
GRANT SELECT_CATALOG_ROLE TO C##DBZUSER CONTAINER=ALL;

SELECT 'C##DBZUSER created with LogMiner privileges' FROM dual;

-- 5b: C##DMSUSER — CDB common user for DMS Binary Reader
-- Binary Reader reads CDB-level redo/archive logs via BFILE. Must connect to CDB root
-- (SID=XE) because PDB context restricts BFILE access to CDB-level files.
-- Common user (C## prefix) required for CDB root authentication.
ALTER SESSION SET CONTAINER = CDB\$ROOT;

DECLARE
    user_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO user_exists FROM cdb_users WHERE username = 'C##DMSUSER';
    IF user_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP USER C##DMSUSER CASCADE';
    END IF;
END;
/

CREATE USER C##DMSUSER IDENTIFIED BY "$ORACLE_PASSWORD"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA 10M ON USERS
    CONTAINER=ALL;

-- Core session and table access
GRANT CREATE SESSION TO C##DMSUSER CONTAINER=ALL;
GRANT SET CONTAINER TO C##DMSUSER CONTAINER=ALL;
GRANT SELECT ANY TABLE TO C##DMSUSER CONTAINER=ALL;
GRANT SELECT ANY TRANSACTION TO C##DMSUSER CONTAINER=ALL;
GRANT SELECT ANY DICTIONARY TO C##DMSUSER CONTAINER=ALL;

-- Binary Reader needs DIRECTORY objects to read redo log files (non-ASM)
GRANT CREATE ANY DIRECTORY TO C##DMSUSER CONTAINER=ALL;
GRANT DROP ANY DIRECTORY TO C##DMSUSER CONTAINER=ALL;

-- Binary Reader requires DBMS_FILE_TRANSFER and DBMS_FILE_GROUP for BFILE access to redo/archive logs
GRANT EXECUTE ON SYS.DBMS_FILE_TRANSFER TO C##DMSUSER CONTAINER=ALL;
GRANT EXECUTE ON SYS.DBMS_FILE_GROUP TO C##DMSUSER CONTAINER=ALL;

SELECT 'C##DMSUSER created with Binary Reader privileges' FROM dual;

-- ============================================================================
-- STEP 6: Restart Database to Apply SPFILE Changes
-- ============================================================================
ALTER SESSION SET CONTAINER = CDB\$ROOT;
SELECT 'Restarting database to apply SPFILE changes...' FROM dual;
SHUTDOWN IMMEDIATE;
STARTUP;

DECLARE
    v_cdb VARCHAR2(3);
BEGIN
    SELECT CDB INTO v_cdb FROM V\$DATABASE;
    IF v_cdb = 'YES' THEN
        EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE ALL OPEN';
        DBMS_OUTPUT.PUT_LINE('All PDBs opened');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Not a container database or PDBs already open');
END;
/

-- ============================================================================
-- STEP 7: Verification
-- ============================================================================
SELECT '========================================' FROM dual;
SELECT 'CDC CONFIGURATION REPORT' FROM dual;
SELECT '========================================' FROM dual;

ALTER SESSION SET CONTAINER = CDB\$ROOT;
SELECT 'Database Name: ' || NAME FROM V\$DATABASE;
SELECT 'Log Mode: ' || LOG_MODE FROM V\$DATABASE;
SELECT 'Supplemental Logging (MIN): ' || SUPPLEMENTAL_LOG_DATA_MIN FROM V\$DATABASE;
SELECT 'Supplemental Logging (ALL): ' || SUPPLEMENTAL_LOG_DATA_ALL FROM V\$DATABASE;

SELECT 'Archive lag target: ' || value || ' seconds' FROM v\$parameter WHERE name = 'archive_lag_target';
SELECT 'MTTR target: ' || value || ' seconds' FROM v\$parameter WHERE name = 'fast_start_mttr_target';

SELECT 'Redo log configuration:' FROM dual;
SELECT group#, bytes/1024/1024 as size_mb, members, status, archived FROM v\$log ORDER BY group#;

-- CDC user verification
SELECT 'C##DBZUSER exists: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END
FROM cdb_users WHERE username = 'C##DBZUSER';

SELECT 'C##DMSUSER exists: ' || CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END
FROM cdb_users WHERE username = 'C##DMSUSER';

SELECT 'Database-level supplemental logging covers ALL tables automatically' FROM dual;

SELECT '========================================' FROM dual;
SELECT 'CDC CONFIGURATION COMPLETED!' FROM dual;
SELECT '========================================' FROM dual;

EXIT;
EOF
    
    # Run CDC configuration
    su - oracle -c "sqlplus /nolog @/tmp/configure_cdc.sql"

    # Clean up
    rm -f /tmp/configure_cdc.sql

    # Archive log cleanup cron — keep 1 day of archive logs
    cat > /opt/oracle/rman_cleanup.sh << 'CLEANUP_EOF'
#!/bin/bash
source /etc/profile.d/oracle-xe-*.sh
export ORACLE_SID=XE
rman target / <<RMAN
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1';
RMAN
CLEANUP_EOF
    chown oracle:oinstall /opt/oracle/rman_cleanup.sh
    chmod +x /opt/oracle/rman_cleanup.sh
    echo "0 */6 * * * oracle /opt/oracle/rman_cleanup.sh >> /var/log/rman_cleanup.log 2>&1" > /etc/cron.d/oracle-archive-cleanup

    # Enable autocommit for all SQL*Plus sessions so manual DML propagates to CDC immediately
    echo "SET AUTOCOMMIT ON;" >> $ORACLE_HOME/sqlplus/admin/glogin.sql

    echo "✓ Oracle CDC configuration completed"
    echo "✓ CDC users: C##DBZUSER (Debezium LogMiner), C##DMSUSER (DMS Binary Reader)"
    echo "✓ Performance: 200MB redo logs, 2-minute archive lag target"
    echo "✓ Archive log cleanup: every 6 hours, keep 1 day"
}

#==============================================================================
# FUNCTION: Test connection
#==============================================================================
test_connection() {
    echo "Testing connection..."
    
    USER_PWD=$(echo "$ORACLE_USER_PASSWORD" | cut -c1-30)
    
    # Create connection test script
    cat > /tmp/test_connection.sql << EOF
SELECT 'CONNECTION_SUCCESS' FROM dual;
EXIT;
EOF

    # Test connection using sqlplus with connect string
    CONNECTION_TEST=$(su - oracle -c "$ORACLE_HOME/bin/sqlplus -s ${ORACLE_USER}/\"$USER_PWD\"@localhost:1521/${ORACLE_PDB} @/tmp/test_connection.sql" 2>&1)

    # Clean up
    rm -f /tmp/test_connection.sql
    
    if echo "$CONNECTION_TEST" | grep -q "CONNECTION_SUCCESS"; then
        echo "✓ Connection test: PASSED"
        echo "✓ Oracle is ready for data generator!"
    else
        echo "⚠ Connection test failed: $CONNECTION_TEST"
    fi
}

#==============================================================================
# FUNCTION: Restart Oracle database properly (OPTIMIZED)
#==============================================================================
restart_oracle_database() {
    echo "Restarting Oracle database..."

    # Set Oracle environment
    set_oracle_environment

    # Stop and start Oracle service
    systemctl stop oracle-xe-${ORACLE_VERSION}
    sleep 5
    systemctl start oracle-xe-${ORACLE_VERSION}

    # Wait for Oracle to be ready
    echo "Waiting for Oracle to start..."
    for i in {1..30}; do
        if su - oracle -c "$ORACLE_HOME/bin/sqlplus -s / as sysdba <<< 'select 1 from dual;'" > /dev/null 2>&1; then
            echo "Oracle is ready"
            break
        fi
        sleep 10
    done

    echo "✓ Oracle database restarted"
}

#==============================================================================
# MAIN EXECUTION (OPTIMIZED FLOW)
#==============================================================================
main() {
    get_passwords
    setup_ebs_volume
    install_packages
    install_oracle
    configure_oracle
    setup_oracle_service
    configure_listener
    restart_oracle_database
    start_and_configure_oracle
    create_oracle_user
    configure_oracle_for_cdc
    test_connection
    
    echo ""
    echo "========================================================================"
    echo "                    ORACLE INSTALLATION COMPLETE                       "
    echo "========================================================================"
    echo "Oracle XE with CDC configuration is ready at $(date)"
    echo "✓ Archive log mode enabled"
    echo "✓ Database-level supplemental logging (covers ALL tables)"
    echo "✓ CDC users: C##DBZUSER (Debezium LogMiner), C##DMSUSER (DMS Binary Reader)"
    echo "✓ Performance: 200MB redo logs, 2-minute archive lag target"
    echo "✓ Ready for Debezium, DMS, and data generators"
    echo "========================================================================"
}

# Execute main function
main
