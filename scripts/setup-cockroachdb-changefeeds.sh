#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Set up CockroachDB changefeeds to MSK Ingest cluster via SSM Run Command.
# Performs: seed tables, enable rangefeeds, create external connections, create changefeeds.
# Self-contained — seeds CockroachDB tables via data generator before creating changefeeds.
#
# Usage:
#   ./scripts/setup-cockroachdb-changefeeds.sh [OPTIONS]
#
# Options:
#   --drop-existing    Drop existing external connections and changefeeds before creating
#   -h, --help         Show this help message

set -euo pipefail

DROP_EXISTING=false
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --drop-existing)  DROP_EXISTING=true; shift ;;
    -h|--help)
      head -15 "$0" | tail -10
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

APP_NAME="${APP_NAME:?APP_NAME must be set}"
ENV_NAME="${ENV_NAME:?ENV_NAME must be set}"

echo "=== CockroachDB Changefeed Setup ==="
echo ""

# Resolve CockroachDB node-1 instance ID
echo "Resolving CockroachDB node-1 instance..."
NODE1_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${APP_NAME}-${ENV_NAME}-cockroachdb-node-1" \
             "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text \
  --region "$REGION")

if [[ -z "$NODE1_ID" || "$NODE1_ID" == "None" ]]; then
  echo "Error: Could not find CockroachDB node-1 instance"
  exit 1
fi
echo "Node-1 instance: $NODE1_ID"

# Resolve MSK Ingest IAM bootstrap servers
echo "Resolving MSK Ingest bootstrap servers..."
BOOTSTRAP_SERVERS=$(aws ssm get-parameter \
  --name "/${APP_NAME}/${ENV_NAME}/msk-ingest-cluster-bootstrap-servers-sasl-iam" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "$REGION")
echo "Bootstrap: ${BOOTSTRAP_SERVERS:0:60}..."

# Resolve topic names
FIN_TOPIC=$(aws ssm get-parameter \
  --name "/${APP_NAME}/${ENV_NAME}/topic-crdb-fin" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "$REGION")

BRK_TOPIC=$(aws ssm get-parameter \
  --name "/${APP_NAME}/${ENV_NAME}/topic-crdb-brk" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "$REGION")

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --region "$REGION")
FIN_MSK_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${APP_NAME}-${ENV_NAME}-cockroach-financial-msk-role"
BRK_MSK_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${APP_NAME}-${ENV_NAME}-cockroach-brokerage-msk-role"

echo "Financial topic: $FIN_TOPIC"
echo "Brokerage topic: $BRK_TOPIC"
echo "Financial MSK role: $FIN_MSK_ROLE_ARN"
echo "Brokerage MSK role: $BRK_MSK_ROLE_ARN"
echo ""

# Helper: run SQL on CockroachDB via SSM
run_sql() {
  local description="$1"
  local sql="$2"

  echo -n "  $description... "
  local result
  result=$(aws ssm send-command \
    --instance-ids "$NODE1_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cockroach sql --insecure --host=localhost:26257 -e \\\"${sql}\\\"\"]" \
    --query "Command.CommandId" \
    --output text \
    --region "$REGION" 2>&1)

  if [[ $? -ne 0 ]]; then
    echo "FAILED (send)"
    echo "    Error: $result"
    return 1
  fi

  # Wait for completion
  local cmd_id="$result"
  for i in $(seq 1 60); do
    local status
    status=$(aws ssm get-command-invocation \
      --command-id "$cmd_id" \
      --instance-id "$NODE1_ID" \
      --query "Status" \
      --output text \
      --region "$REGION" 2>/dev/null || echo "Pending")

    if [[ "$status" == "Success" ]]; then
      echo "OK"
      return 0
    elif [[ "$status" == "Failed" || "$status" == "TimedOut" || "$status" == "Cancelled" ]]; then
      echo "FAILED ($status)"
      aws ssm get-command-invocation \
        --command-id "$cmd_id" \
        --instance-id "$NODE1_ID" \
        --query "StandardErrorContent" \
        --output text \
        --region "$REGION" 2>/dev/null | tail -3 | sed 's/^/    /'
      return 1
    fi
    sleep 2
  done
  echo "TIMEOUT"
  return 1
}

# Step 1: Verify tables exist (created by `make setup-source-tables`)
echo "Step 1: Verify CockroachDB tables exist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TABLE_CHECK=$(aws ssm send-command \
  --instance-ids "$NODE1_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"cockroach sql --insecure --host=localhost:26257 -e \\\"SELECT count(*) FROM information_schema.tables WHERE table_name IN ('financial_transactions','brokerage_transactions');\\\"\"]" \
  --query "Command.CommandId" \
  --output text \
  --region "$REGION" 2>&1)
sleep 5
TABLE_COUNT=$(aws ssm get-command-invocation \
  --command-id "$TABLE_CHECK" \
  --instance-id "$NODE1_ID" \
  --query "StandardOutputContent" \
  --output text \
  --region "$REGION" 2>/dev/null | grep -o '[0-9]' | tail -1)
if [[ "$TABLE_COUNT" != "2" ]]; then
  echo "  Tables not found. Creating via data generator (--count 0)..."
  bash "${SCRIPT_DIR}/generate-data.sh" --source cockroach --count 0 --wait
else
  echo "  Both tables exist. Skipping creation."
fi
echo ""

# Step 2: Enable rangefeeds
echo "Step 2: Enable rangefeeds"
run_sql "SET kv.rangefeed.enabled = true" \
  "SET CLUSTER SETTING kv.rangefeed.enabled = true;"

echo ""

# Step 3: Drop existing (if requested)
if [[ "$DROP_EXISTING" == true ]]; then
  echo "Step 3: Dropping existing changefeeds and external connections"
  run_sql "Cancel running changefeeds" \
    "CANCEL ALL CHANGEFEED JOBS;" || true
  sleep 2
  run_sql "Drop msk_financial connection" \
    "DROP EXTERNAL CONNECTION msk_financial;" || true
  run_sql "Drop msk_brokerage connection" \
    "DROP EXTERNAL CONNECTION msk_brokerage;" || true
  echo ""
else
  echo "Step 3: Skipped (no --drop-existing flag)"
  echo ""
fi

# Step 4: Create external connections
echo "Step 4: Create external connections to MSK Ingest"
run_sql "Create msk_financial external connection" \
  "CREATE EXTERNAL CONNECTION msk_financial AS 'kafka://${BOOTSTRAP_SERVERS}?topic_name=${FIN_TOPIC}&sasl_enabled=true&sasl_mechanism=AWS_MSK_IAM&sasl_aws_region=${REGION}&sasl_aws_iam_role_arn=${FIN_MSK_ROLE_ARN}&sasl_aws_iam_session_name=cockroachdb-changefeed-financial&tls_enabled=true';"

run_sql "Create msk_brokerage external connection" \
  "CREATE EXTERNAL CONNECTION msk_brokerage AS 'kafka://${BOOTSTRAP_SERVERS}?topic_name=${BRK_TOPIC}&sasl_enabled=true&sasl_mechanism=AWS_MSK_IAM&sasl_aws_region=${REGION}&sasl_aws_iam_role_arn=${BRK_MSK_ROLE_ARN}&sasl_aws_iam_session_name=cockroachdb-changefeed-brokerage&tls_enabled=true';"

echo ""

# Step 5: Create changefeeds
echo "Step 5: Create changefeeds"
run_sql "Create financial_transactions changefeed" \
  "CREATE CHANGEFEED FOR TABLE defaultdb.financial_transactions INTO 'external://msk_financial' WITH format = json, updated, resolved = '30s', envelope = 'enriched', key_in_value;"

run_sql "Create brokerage_transactions changefeed" \
  "CREATE CHANGEFEED FOR TABLE defaultdb.brokerage_transactions INTO 'external://msk_brokerage' WITH format = json, updated, resolved = '30s', envelope = 'enriched', key_in_value;"

echo ""
echo "=== Changefeed setup complete ==="
echo ""
echo "Verify with: make connect-to-cockroach"
echo "  cockroach sql --insecure --host=localhost:26257 -e \"SHOW CHANGEFEED JOBS;\""
