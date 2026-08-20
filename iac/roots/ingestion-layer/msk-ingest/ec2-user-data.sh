#!/bin/bash -ex
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "STARTING MSK TOPIC CREATION SCRIPT"

# Export template variables to make them available globally
export MSK_CLUSTER_NAME=${msk_cluster_name}
export REGION=${aws_region}
export TOPIC_LIST=${topic_list}
export KAFKA_CLIENT_VERSION=${kafka_client_version}

CLUSTER_ARN=$(aws kafka list-clusters-v2 --region $REGION --output text --cluster-name $MSK_CLUSTER_NAME --query 'ClusterInfoList[*].ClusterArn')

# Get specific bootstrap servers for SASL/SCRAM authentication (port 9096)
BOOTSTRAP_SERVER_SASL_SCRAM=$(aws kafka get-bootstrap-brokers --cluster-arn $CLUSTER_ARN --query 'BootstrapBrokerStringSaslScram' --output text)

# Get IAM bootstrap servers as backup (port 9098)  
BOOTSTRAP_SERVER_IAM=$(aws kafka get-bootstrap-brokers --cluster-arn $CLUSTER_ARN --query 'BootstrapBrokerStringSaslIam' --output text)

# Use SASL/SCRAM as primary
BOOTSTRAP_SERVER=$BOOTSTRAP_SERVER_SASL_SCRAM

# Export dynamic variables
export CLUSTER_ARN
export BOOTSTRAP_SERVER_SASL_SCRAM
export BOOTSTRAP_SERVER_IAM
export BOOTSTRAP_SERVER

# Make environment variables available to all users via /etc/profile.d/
cat > /etc/profile.d/msk-env.sh << EOF
export MSK_CLUSTER_NAME="${msk_cluster_name}"
export REGION="${aws_region}"
export TOPIC_LIST="${topic_list}"
export KAFKA_CLIENT_VERSION="${kafka_client_version}"
export CLUSTER_ARN="$CLUSTER_ARN"
export BOOTSTRAP_SERVER_SASL_SCRAM="$BOOTSTRAP_SERVER_SASL_SCRAM"
export BOOTSTRAP_SERVER_IAM="$BOOTSTRAP_SERVER_IAM"
export BOOTSTRAP_SERVER="$BOOTSTRAP_SERVER"
EOF

chmod +x /etc/profile.d/msk-env.sh

echo "Environment variables configured. Available variables:"
echo "MSK_CLUSTER_NAME=$MSK_CLUSTER_NAME"
echo "REGION=$REGION"
echo "TOPIC_LIST=$TOPIC_LIST"
echo "KAFKA_CLIENT_VERSION=$KAFKA_CLIENT_VERSION"
echo "CLUSTER_ARN=$CLUSTER_ARN"
echo "BOOTSTRAP_SERVER_SASL_SCRAM=$BOOTSTRAP_SERVER_SASL_SCRAM"
echo "BOOTSTRAP_SERVER_IAM=$BOOTSTRAP_SERVER_IAM"
echo "BOOTSTRAP_SERVER=$BOOTSTRAP_SERVER"

echo "Installing dependencies..."
yum -y install java-11
yum -y install wget

wget https://archive.apache.org/dist/kafka/$KAFKA_CLIENT_VERSION/kafka_2.13-$KAFKA_CLIENT_VERSION.tgz
tar -xzf kafka_2.13-$KAFKA_CLIENT_VERSION.tgz
cd kafka_2.13-$KAFKA_CLIENT_VERSION/libs
wget https://github.com/aws/aws-msk-iam-auth/releases/download/v1.1.1/aws-msk-iam-auth-1.1.1-all.jar
cd ../bin

echo "Installing jq for JSON parsing..."
yum -y install jq

echo "Retrieving SASL/SCRAM credentials from Secrets Manager..."
SECRET_NAME="AmazonMSK_$MSK_CLUSTER_NAME-credentials" # pragma: allowlist secret
echo "Fetching secret: $SECRET_NAME"

SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --region "$REGION" --query SecretString --output text)
USERNAME=$(echo "$SECRET_VALUE" | jq -r '.username')
PASSWORD=$(echo "$SECRET_VALUE" | jq -r '.password')  # pragma: allowlist secret

echo "Creating SASL/SCRAM client properties file..."
cat > client.properties << EOF
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="$USERNAME" password="$PASSWORD";
EOF

echo "Creating IAM client properties file as backup..."
cat > client-iam.properties << EOF
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
EOF

create_topic_if_not_exists() {
    local topic_name=$1
    local replication_factor=$2
    local partitions=$3
    
    echo "Checking if topic '$topic_name' exists..."
    
    # Use the same variables that work for manual commands
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
TOPIC_LIST_CLEAN=$(echo "$TOPIC_LIST" | sed 's/[()"]//g')
IFS=',' read -ra TOPIC_ARRAY <<< "$TOPIC_LIST_CLEAN"

for topic in "$${TOPIC_ARRAY[@]}"
do
    # Trim whitespace from topic name
    topic=$(echo "$topic" | xargs)
    if [ -n "$topic" ]; then
        create_topic_if_not_exists "$topic" 3 1
    fi
done

echo "Current Kafka topics: "
./kafka-topics.sh --list --bootstrap-server $BOOTSTRAP_SERVER --command-config client.properties