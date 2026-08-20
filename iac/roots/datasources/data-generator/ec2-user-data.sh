#!/bin/bash -ex
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "STARTING DATA GENERATOR SETUP SCRIPT"

#==============================================================================
# FUNCTION: Download files with retry logic
#==============================================================================
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_attempts=5
    local attempt=1
    local wait_time=5

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts: Downloading $output"
        
        if wget -O "$output" "$url"; then
            echo "✓ Download successful: $output"
            return 0
        else
            echo "⚠ Download failed. Waiting $wait_time seconds before retry..."
            sleep $wait_time
            wait_time=$((wait_time * 2))
            attempt=$((attempt + 1))
        fi
    done
    
    echo "❌ Failed to download $output after $max_attempts attempts"
    return 1
}

REGION=${aws_region}
ASSETS_BUCKET=${assets_bucket}

ENABLE_MSK=${enable_msk}
ENABLE_ORACLE=${enable_oracle}
ENABLE_AURORA=${enable_aurora}
ENABLE_COCKROACH=${enable_cockroach}

# MSK Source
MSK_SECRET_NAME=${msk_secret_name}
MSK_CLUSTER_NAME=${msk_cluster_name}
MSK_SOURCE_TOPIC_LIST=${msk_source_topic_list}

# Oracle
ORACLE_SECRET_NAME=${oracle_secret_name}
ORACLE_FINANCIAL_TRANSACTIONS_TABLE_NAME=${oracle_financial_transactions_table_name}
ORACLE_BROKERAGE_TRANSACTIONS_TABLE_NAME=${oracle_brokerage_transactions_table_name}

# Aurora
AURORA_SECRET_NAME=${aurora_secret_name}
AURORA_FINANCIAL_TRANSACTIONS_TABLE_NAME=${aurora_financial_transactions_table_name}
AURORA_BROKERAGE_TRANSACTIONS_TABLE_NAME=${aurora_brokerage_transactions_table_name}

# Cockroach
COCKROACH_SECRET_NAME=${cockroach_secret_name}
COCKROACH_FINANCIAL_TRANSACTIONS_TABLE_NAME=${cockroach_financial_transactions_table_name}
COCKROACH_BROKERAGE_TRANSACTIONS_TABLE_NAME=${cockroach_brokerage_transactions_table_name}

# Kafka Client
KAFKA_VERSION="3.9.1"

# Set environment variables once for the script
export JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto
export KAFKA_HOME="/kafka_2.13-$KAFKA_VERSION"
export PATH=$JAVA_HOME/bin:$PATH

echo "Installing dependencies..."
yum update -y
yum -y install java-21-amazon-corretto-devel maven wget unzip

echo "Java version:"
java -version
echo "Maven version:"
mvn -version

echo "Persisting environment variables for interactive use..."

# Ensure .bashrc exists and has proper ownership
touch /home/ec2-user/.bashrc
chown ec2-user:ec2-user /home/ec2-user/.bashrc

echo "Writing to .bashrc..."
cat >> /home/ec2-user/.bashrc << EOF

export REGION="$REGION"
export ASSETS_BUCKET="$ASSETS_BUCKET"

export ENABLE_MSK="$ENABLE_MSK"
export ENABLE_ORACLE="$ENABLE_ORACLE"
export ENABLE_AURORA="$ENABLE_AURORA"
export ENABLE_COCKROACH="$ENABLE_COCKROACH"

export MSK_SECRET_NAME="$MSK_SECRET_NAME"
export MSK_CLUSTER_NAME="$MSK_CLUSTER_NAME"
export MSK_SOURCE_TOPIC_LIST="$MSK_SOURCE_TOPIC_LIST"

export ORACLE_SECRET_NAME="$ORACLE_SECRET_NAME"
export ORACLE_FINANCIAL_TRANSACTIONS_TABLE_NAME="$ORACLE_FINANCIAL_TRANSACTIONS_TABLE_NAME"
export ORACLE_BROKERAGE_TRANSACTIONS_TABLE_NAME="$ORACLE_BROKERAGE_TRANSACTIONS_TABLE_NAME"

export AURORA_SECRET_NAME="$AURORA_SECRET_NAME"
export AURORA_FINANCIAL_TRANSACTIONS_TABLE_NAME="$AURORA_FINANCIAL_TRANSACTIONS_TABLE_NAME"
export AURORA_BROKERAGE_TRANSACTIONS_TABLE_NAME="$AURORA_BROKERAGE_TRANSACTIONS_TABLE_NAME"

export COCKROACH_SECRET_NAME="$COCKROACH_SECRET_NAME"
export COCKROACH_FINANCIAL_TRANSACTIONS_TABLE_NAME="$COCKROACH_FINANCIAL_TRANSACTIONS_TABLE_NAME"
export COCKROACH_BROKERAGE_TRANSACTIONS_TABLE_NAME="$COCKROACH_BROKERAGE_TRANSACTIONS_TABLE_NAME"

export KAFKA_VERSION="$KAFKA_VERSION"

export JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
export KAFKA_HOME="/kafka_2.13-$KAFKA_VERSION"
export PATH="\$JAVA_HOME/bin:\$PATH:\$KAFKA_HOME/bin"
EOF

echo "Finished writing to .bashrc"

# Set ownership and permissions
chown ec2-user:ec2-user /home/ec2-user/.bashrc
chmod 644 /home/ec2-user/.bashrc
source /home/ec2-user/.bashrc
chmod 644 /home/ec2-user/.bashrc

echo "Environment variables persisted to /etc/environment and /home/ec2-user/.bashrc"

# Only install and configure Kafka if MSK is enabled
if [ "$ENABLE_MSK" = "true" ]; then
    echo "Installing Kafka for topic management..."

    CLUSTER_ARN=$(aws kafka list-clusters-v2 --region $REGION --output text --cluster-name $MSK_CLUSTER_NAME --query 'ClusterInfoList[*].ClusterArn')
    BOOTSTRAP_SERVER=$(aws kafka get-bootstrap-brokers --cluster-arn $${CLUSTER_ARN} --output text)

    # Download Kafka with retry
    download_with_retry \
        "https://archive.apache.org/dist/kafka/$KAFKA_VERSION/kafka_2.13-$KAFKA_VERSION.tgz" \
        "kafka_2.13-$KAFKA_VERSION.tgz"

    if [ $? -ne 0 ]; then
        echo "❌ Failed to download Kafka after multiple attempts"
        exit 1
    fi

    tar -xzf kafka_2.13-$KAFKA_VERSION.tgz
    cd kafka_2.13-$KAFKA_VERSION/libs

    # Download MSK IAM Auth JAR with retry
    download_with_retry \
        "https://github.com/aws/aws-msk-iam-auth/releases/download/v1.1.1/aws-msk-iam-auth-1.1.1-all.jar" \
        "aws-msk-iam-auth-1.1.1-all.jar"

    if [ $? -ne 0 ]; then
        echo "❌ Failed to download MSK IAM Auth JAR after multiple attempts"
        exit 1
    fi

    cd ../bin

    mkdir -p /etc/kafka
    cat > /etc/kafka/client.properties << EOF
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
EOF

    # Also create client properties in the Kafka bin directory for immediate use
    cat > client.properties << EOF
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
EOF

    # Add Kafka bin directory to PATH in environment files
    echo "KAFKA_HOME=/kafka_2.13-$KAFKA_VERSION" >> /etc/environment
    echo "PATH=/usr/lib/jvm/java-21-amazon-corretto/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin:/kafka_2.13-$KAFKA_VERSION/bin" >> /etc/environment

    # Also add to .bashrc
    cat >> /home/ec2-user/.bashrc << EOF
export KAFKA_HOME="/kafka_2.13-$KAFKA_VERSION"
export PATH="\$JAVA_HOME/bin:\$PATH:\$KAFKA_HOME/bin"
EOF

    create_msk_topic_if_not_exists() {
        local topic_name=$1
        local replication_factor=$2
        local partitions=$3
        
        echo "Checking if topic '$topic_name' exists..."
        
        # List topics and check if the topic exists
        topic_exists=$(./kafka-topics.sh --list --bootstrap-server $BOOTSTRAP_SERVER --command-config client.properties | grep "^$topic_name$" || true)
        
        if [ -z "$topic_exists" ]; then
            echo "Topic '$topic_name' does not exist. Creating..."
            ./kafka-topics.sh --create --bootstrap-server $BOOTSTRAP_SERVER --command-config client.properties \
                --replication-factor $replication_factor --partitions $partitions --topic $topic_name
            echo "Topic '$topic_name' created successfully."
        else
            echo "Topic '$topic_name' already exists. Skipping creation."
        fi
    }

    # Parse topic list from format ("topic1","topic2","topic3","topicN") to array
    # Remove parentheses and quotes, but keep commas for splitting
    TOPIC_LIST_CLEAN=$(echo "$MSK_SOURCE_TOPIC_LIST" | sed 's/[()"]//g')
    IFS=',' read -ra TOPIC_ARRAY <<< "$TOPIC_LIST_CLEAN"

    for topic in "$${TOPIC_ARRAY[@]}"
    do
        # Trim whitespace from topic name
        topic=$(echo "$topic" | xargs)
        if [ -n "$topic" ]; then
            create_msk_topic_if_not_exists "$topic" 3 1
        fi
    done

    # Extract individual topic names by pattern matching (safer than array position)
    MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME=""
    MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME=""

    for topic in "$${TOPIC_ARRAY[@]}"; do
        topic=$(echo "$topic" | xargs)
        if [[ "$topic" == *"fin"* ]]; then
            MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME="$topic"
        elif [[ "$topic" == *"brk"* ]]; then
            MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME="$topic"
        fi
    done

    echo "Identified topics:"
    echo "  Financial: $MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME"
    echo "  Brokerage: $MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME"

    # Export topic names to .bashrc after identification
    cat >> /home/ec2-user/.bashrc << EOF

    export MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME="$MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME"
    export MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME="$MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME"
EOF

    echo "Current Kafka topics: "
        ./kafka-topics.sh --list --bootstrap-server $BOOTSTRAP_SERVER --command-config client.properties
    else
        echo "MSK is disabled (ENABLE_MSK=$ENABLE_MSK). Skipping Kafka installation and topic management."
    fi

echo "Getting Data generator source code from s3"
cd /
mkdir -p data-generator
aws s3 cp s3://$ASSETS_BUCKET/data-generator/source.zip data-generator/source.zip

echo "Extracting and building data generator..."
cd /data-generator

# Extract with verbose output to see what's inside
echo "Extracting source.zip..."
unzip -q source.zip

# Find where the pom.xml file is located
echo "Looking for pom.xml file..."
find . -name "pom.xml" -type f

# Find the directory with Java source code
GENERATOR_DIR=$(find . -name "pom.xml" -type f | head -1 | xargs dirname)

if [ -z "$GENERATOR_DIR" ]; then
    echo "ERROR: Could not find pom.xml file in extracted contents"
    exit 1
fi

echo "Found generator directory at: $GENERATOR_DIR"

# Build the application
echo "Building Java application with Maven..."
cd "$GENERATOR_DIR"

# Build with Maven using explicit Java version
JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto mvn clean package -q

# Find the built JAR with dependencies (the executable one)
JAR_FILE=$(find target -name "*-jar-with-dependencies.jar" | head -1)

if [ -z "$JAR_FILE" ]; then
    echo "ERROR: Could not find JAR with dependencies. Looking for any JAR..."
    JAR_FILE=$(find target -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" | head -1)
    
    if [ -z "$JAR_FILE" ]; then
        echo "ERROR: Could not find any built JAR file"
        echo "Contents of target directory:"
        ls -la target/
        exit 1
    fi
    
    echo "WARNING: Using regular JAR instead of fat JAR: $JAR_FILE"
    echo "This may not work if dependencies are missing"
fi

echo "Found JAR file: $JAR_FILE"

# Copy the built JAR to the expected location
cp "$JAR_FILE" /data-generator/generator.jar

echo "Data generator build completed successfully!"

#==============================================================================
# FUNCTION: Create scripts conditionally based on enabled services
#==============================================================================
create_conditional_scripts() {
    echo "Creating scripts for enabled services only..."
    
    # Create base directories for organization
    mkdir -p /home/ec2-user/scripts
    
    #==========================================================================
    # MSK SCRIPTS (Only if MSK is enabled)
    #==========================================================================
    if [ "$ENABLE_MSK" = "true" ]; then
        echo "Creating MSK scripts (MSK is enabled)..."
        mkdir -p /home/ec2-user/msk
        
        # Create MSK data generator script for financial transactions
        cat > /home/ec2-user/msk/run-msk-financial.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS financial transaction records to MSK..."

cd /data-generator
java -jar generator.jar \
    --enable-msk \
    --bootstrap-servers-secret "$MSK_SECRET_NAME" \
    --topic "$MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME" \
    --transaction-type "financial" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Create MSK data generator script for brokerage transactions
        cat > /home/ec2-user/msk/run-msk-brokerage.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS brokerage transaction records to MSK..."

cd /data-generator
java -jar generator.jar \
    --enable-msk \
    --bootstrap-servers-secret "$MSK_SECRET_NAME" \
    --topic "$MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME" \
    --transaction-type "brokerage" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Create MSK data generator script for both transaction types
        cat > /home/ec2-user/msk/run-msk-both.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS records of both transaction types to MSK (using multithreading)..."

cd /data-generator

# Run both generators in parallel
java -jar generator.jar \
    --enable-msk \
    --bootstrap-servers-secret "$MSK_SECRET_NAME" \
    --topic "$MSK_FINANCIAL_TRANSACTIONS_TOPIC_NAME" \
    --transaction-type "financial" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@" &

java -jar generator.jar \
    --enable-msk \
    --bootstrap-servers-secret "$MSK_SECRET_NAME" \
    --topic "$MSK_BROKERAGE_TRANSACTIONS_TOPIC_NAME" \
    --transaction-type "brokerage" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@" &

# Wait for both background processes to complete
wait
echo "Completed generating $RECORDS records to both topics in parallel."
EOF

        # Make MSK scripts executable and set ownership
        find /home/ec2-user/msk -name "*.sh" -exec chmod +x {} \;
        chown -R ec2-user:ec2-user /home/ec2-user/msk
        
        echo "✓ MSK scripts created successfully"
    else
        echo "⚠ MSK is disabled (ENABLE_MSK=$ENABLE_MSK). Skipping MSK script creation."
    fi

    #==========================================================================
    # ORACLE SCRIPTS (Only if Oracle is enabled)
    #==========================================================================
    if [ "$ENABLE_ORACLE" = "true" ]; then
        echo "Creating Oracle scripts (Oracle is enabled)..."
        mkdir -p /home/ec2-user/oracle
        
        # Create Oracle data generator script for financial transactions
        cat > /home/ec2-user/oracle/run-oracle-financial.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS financial transaction records to Oracle..."

cd /data-generator
java -jar generator.jar \
    --enable-database \
    --db-secret "$ORACLE_SECRET_NAME" \
    --table-name "$ORACLE_FINANCIAL_TRANSACTIONS_TABLE_NAME" \
    --transaction-type "financial" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Create Oracle data generator script for brokerage transactions
        cat > /home/ec2-user/oracle/run-oracle-brokerage.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS brokerage transaction records to Oracle..."

cd /data-generator
java -jar generator.jar \
    --enable-database \
    --db-secret "$ORACLE_SECRET_NAME" \
    --table-name "$ORACLE_BROKERAGE_TRANSACTIONS_TABLE_NAME" \
    --transaction-type "brokerage" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Create Oracle data generator script for both transaction types
        cat > /home/ec2-user/oracle/run-oracle-both.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS records of both transaction types to Oracle..."

cd /data-generator
java -jar generator.jar \
    --enable-database \
    --db-secret "$ORACLE_SECRET_NAME" \
    --transaction-type "both" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Make Oracle scripts executable and set ownership
        find /home/ec2-user/oracle -name "*.sh" -exec chmod +x {} \;
        chown -R ec2-user:ec2-user /home/ec2-user/oracle
        
        echo "✓ Oracle scripts created successfully"
    else
        echo "⚠ Oracle is disabled (ENABLE_ORACLE=$ENABLE_ORACLE). Skipping Oracle script creation."
    fi

    #==========================================================================
    # AURORA SCRIPTS (Only if Aurora is enabled)
    #==========================================================================
    if [ "$ENABLE_AURORA" = "true" ]; then
        echo "Creating Aurora scripts (Aurora is enabled)..."
        mkdir -p /home/ec2-user/aurora
        
        # Create Aurora data generator script for financial transactions
        cat > /home/ec2-user/aurora/run-aurora-financial.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS financial transaction records to Aurora PostgreSQL..."

cd /data-generator
java -jar generator.jar \
    --enable-database \
    --db-secret "$AURORA_SECRET_NAME" \
    --table-name "$AURORA_FINANCIAL_TRANSACTIONS_TABLE_NAME" \
    --transaction-type "financial" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Create Aurora data generator script for brokerage transactions
        cat > /home/ec2-user/aurora/run-aurora-brokerage.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS brokerage transaction records to Aurora PostgreSQL..."

cd /data-generator
java -jar generator.jar \
    --enable-database \
    --db-secret "$AURORA_SECRET_NAME" \
    --table-name "$AURORA_BROKERAGE_TRANSACTIONS_TABLE_NAME" \
    --transaction-type "brokerage" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Create Aurora data generator script for both transaction types
        cat > /home/ec2-user/aurora/run-aurora-both.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS records of both transaction types to Aurora PostgreSQL..."

cd /data-generator
java -jar generator.jar \
    --enable-database \
    --db-secret "$AURORA_SECRET_NAME" \
    --transaction-type "both" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Make Aurora scripts executable and set ownership
        find /home/ec2-user/aurora -name "*.sh" -exec chmod +x {} \;
        chown -R ec2-user:ec2-user /home/ec2-user/aurora

        echo "✓ Aurora scripts created successfully"
    else
        echo "⚠ Aurora is disabled (ENABLE_AURORA=$ENABLE_AURORA). Skipping Aurora script creation."
    fi

    #==========================================================================
    # COCKROACH SCRIPTS (Only if CockroachDB is enabled)
    #==========================================================================
    if [ "$ENABLE_COCKROACH" = "true" ]; then
        echo "Creating CockroachDB scripts (CockroachDB is enabled)..."
        mkdir -p /home/ec2-user/cockroach
        
        # Create CockroachDB data generator script for financial transactions
        cat > /home/ec2-user/cockroach/run-cockroach-financial.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS financial transaction records to CockroachDB..."

cd /data-generator
java -jar generator.jar \
    --enable-database \
    --db-secret "$COCKROACH_SECRET_NAME" \
    --table-name "$COCKROACH_FINANCIAL_TRANSACTIONS_TABLE_NAME" \
    --transaction-type "financial" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Create CockroachDB data generator script for brokerage transactions
        cat > /home/ec2-user/cockroach/run-cockroach-brokerage.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS brokerage transaction records to CockroachDB..."

cd /data-generator
java -jar generator.jar \
    --enable-database \
    --db-secret "$COCKROACH_SECRET_NAME" \
    --table-name "$COCKROACH_BROKERAGE_TRANSACTIONS_TABLE_NAME" \
    --transaction-type "brokerage" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Create CockroachDB data generator script for both transaction types
        cat > /home/ec2-user/cockroach/run-cockroach-both.sh << 'EOF'
#!/bin/bash
RECORDS=$${1:-1000}; shift 2>/dev/null || true

echo "Generating $RECORDS records of both transaction types to CockroachDB..."

cd /data-generator
java -jar generator.jar \
    --enable-database \
    --db-secret "$COCKROACH_SECRET_NAME" \
    --transaction-type "both" \
    --num-records "$RECORDS" \
    --region "$REGION" "$@"
EOF

        # Make CockroachDB scripts executable and set ownership
        find /home/ec2-user/cockroach -name "*.sh" -exec chmod +x {} \;
        chown -R ec2-user:ec2-user /home/ec2-user/cockroach
        
        echo "✓ CockroachDB scripts created successfully"
    else
        echo "⚠ CockroachDB is disabled (ENABLE_COCKROACH=$ENABLE_COCKROACH). Skipping CockroachDB script creation."
    fi
        
    #==========================================================================
    # CREATE SUMMARY SCRIPT
    #==========================================================================
    cat > /home/ec2-user/show-available-scripts.sh << 'EOF'
#!/bin/bash
echo "=== AVAILABLE DATA GENERATOR SCRIPTS ==="
echo ""

if [ "$ENABLE_MSK" = "true" ] && [ -d "/home/ec2-user/msk" ]; then
    echo "📊 MSK Scripts (Kafka):"
    ls -la /home/ec2-user/msk/*.sh 2>/dev/null | awk '{print "  " $9}' | grep -v "^  $"
    echo ""
fi

if [ "$ENABLE_ORACLE" = "true" ] && [ -d "/home/ec2-user/oracle" ]; then
    echo "🗄️  Oracle Scripts:"
    ls -la /home/ec2-user/oracle/*.sh 2>/dev/null | awk '{print "  " $9}' | grep -v "^  $"
    echo ""
fi

if [ "$ENABLE_AURORA" = "true" ] && [ -d "/home/ec2-user/aurora" ]; then
    echo "🐘 Aurora Scripts:"
    ls -la /home/ec2-user/aurora/*.sh 2>/dev/null | awk '{print "  " $9}' | grep -v "^  $"
    echo ""
fi

if [ "$ENABLE_COCKROACH" = "true" ] && [ -d "/home/ec2-user/cockroach" ]; then
    echo "🦗 CockroachDB Scripts:"
    ls -la /home/ec2-user/cockroach/*.sh 2>/dev/null | awk '{print "  " $9}' | grep -v "^  $"
    echo ""
fi

echo "Usage examples:"
if [ "$ENABLE_MSK" = "true" ]; then
    echo "  ./msk/run-msk-financial.sh 1000"
fi
if [ "$ENABLE_ORACLE" = "true" ]; then
    echo "  ./oracle/run-oracle-both.sh 500"
fi
if [ "$ENABLE_AURORA" = "true" ]; then
    echo "  ./aurora/run-aurora-brokerage.sh 2000"
fi
if [ "$ENABLE_COCKROACH" = "true" ]; then
    echo "  ./cockroach/run-cockroach-both.sh 1500"
fi
EOF

    chmod +x /home/ec2-user/show-available-scripts.sh
    chown ec2-user:ec2-user /home/ec2-user/show-available-scripts.sh

    echo "✓ Conditional script creation completed"
    echo "✓ Created summary script: ./show-available-scripts.sh"
}

#==============================================================================
# CREATE SCRIPTS CONDITIONALLY BASED ON ENABLED SERVICES
#==============================================================================
create_conditional_scripts

echo "SETUP COMPLETE - Data generator is ready for use!"
echo ""
echo "=== ENABLED SERVICES ==="
echo "MSK: $ENABLE_MSK"
echo "Oracle: $ENABLE_ORACLE" 
echo "Aurora: $ENABLE_AURORA"
echo "CockroachDB: $ENABLE_COCKROACH"
echo ""
echo "Run './show-available-scripts.sh' to see available scripts for your enabled services."
