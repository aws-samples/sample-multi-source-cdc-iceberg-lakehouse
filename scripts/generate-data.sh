#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Trigger test data generation across all sources via SSM Run Command.
# No SSH required — runs entirely from your local machine.
#
# Usage:
#   ./scripts/generate-data.sh [OPTIONS]
#
# Options:
#   -s, --source SOURCE    Source to generate (oracle|aurora|cockroach|msk|all) [default: all]
#   -t, --type TYPE        Transaction type (both|financial|brokerage) [default: both]
#   -n, --count COUNT      Number of records [default: 1000]
#   -i, --interval MS      Delay between records in milliseconds [default: 1000]
#   -T, --threads NUM      Parallel threads per destination [default: 1]
#   -w, --wait             Wait for all commands to complete and show results
#   -h, --help             Show this help message
#
# Examples:
#   make generate-data                                     # All sources, 1000 records each
#   make generate-data args="--count 500"                  # All sources, 500 records each
#   make generate-data args="--source oracle"              # Oracle only, 1000 records
#   make generate-data args="-s aurora -t financial -n 200"  # Aurora financial, 200 records
#   make generate-data args="--interval 100 --threads 4"   # Fast: 100ms delay, 4 threads
#   make generate-data args="-i 0 -T 10"                   # Max throughput: no delay, 10 threads

set -euo pipefail

# Defaults
SOURCE="all"
TYPE="both"
COUNT="1000"
INTERVAL=""
THREADS=""
WAIT=false
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--source)  SOURCE="$2"; shift 2 ;;
    -t|--type)    TYPE="$2";   shift 2 ;;
    -n|--count)     COUNT="$2";    shift 2 ;;
    -i|--interval)  INTERVAL="$2"; shift 2 ;;
    -T|--threads)   THREADS="$2";  shift 2 ;;
    -w|--wait)      WAIT=true;     shift   ;;
    -h|--help)
      head -27 "$0" | tail -22
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate inputs
VALID_SOURCES="oracle aurora cockroach msk all"
VALID_TYPES="both financial brokerage"
if [[ ! " $VALID_SOURCES " =~ " $SOURCE " ]]; then
  echo "Error: Invalid source '$SOURCE'. Must be one of: $VALID_SOURCES"
  exit 1
fi
if [[ ! " $VALID_TYPES " =~ " $TYPE " ]]; then
  echo "Error: Invalid type '$TYPE'. Must be one of: $VALID_TYPES"
  exit 1
fi

APP_NAME="${APP_NAME:?APP_NAME must be set}"
ENV_NAME="${ENV_NAME:?ENV_NAME must be set}"

# Build extra Java args for interval/threads
EXTRA_ARGS=""
if [[ -n "$INTERVAL" ]]; then
  EXTRA_ARGS="${EXTRA_ARGS} --interval ${INTERVAL}"
fi
if [[ -n "$THREADS" ]]; then
  EXTRA_ARGS="${EXTRA_ARGS} --threads ${THREADS}"
fi

echo "=== Data Generator ==="
echo -n "Source: $SOURCE | Type: $TYPE | Count: $COUNT"
if [[ -n "$INTERVAL" ]]; then echo -n " | Interval: ${INTERVAL}ms"; fi
if [[ -n "$THREADS" ]]; then echo -n " | Threads: ${THREADS}"; fi
echo ""
echo ""

# Resolve EC2 instance ID
echo "Resolving data generator instance..."
DATAGEN_IP=$(aws ssm get-parameter \
  --name "/${APP_NAME}/${ENV_NAME}/data-generator-host" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "$REGION")

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=private-ip-address,Values=${DATAGEN_IP}" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text \
  --region "$REGION")

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "Error: Could not resolve data generator instance ID"
  exit 1
fi
echo "Instance: $INSTANCE_ID"
echo ""

# Function to send SSM command for a source
send_command() {
  local source="$1"
  local script="run-${source}-${TYPE}.sh"
  local cmd="source /home/ec2-user/.bashrc && cd /home/ec2-user/${source} && bash ${script} ${COUNT}${EXTRA_ARGS}"

  local command_id
  command_id=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"${cmd}\"]" \
    --query "Command.CommandId" \
    --output text \
    --region "$REGION" 2>&1)

  if [[ $? -eq 0 ]]; then
    echo "  [SENT] ${source} → ${script} ${COUNT} records (Command: ${command_id})"
    echo "$command_id"
  else
    echo "  [FAIL] ${source} → Could not send command: ${command_id}"
    echo ""
  fi
}

# Determine which sources to run
if [[ "$SOURCE" == "all" ]]; then
  SOURCES=("oracle" "aurora" "cockroach" "msk")
else
  SOURCES=("$SOURCE")
fi

# Fire commands
echo "Sending SSM commands..."
declare -A COMMAND_IDS
for src in "${SOURCES[@]}"; do
  result=$(send_command "$src")
  # Last line is the command ID
  cmd_id=$(echo "$result" | tail -1)
  # Print all but last line (the status messages)
  line_count=$(echo "$result" | wc -l)
  if [[ $line_count -gt 1 ]]; then
    echo "$result" | sed '$d'
  fi
  if [[ -n "$cmd_id" ]]; then
    COMMAND_IDS["$src"]="$cmd_id"
  fi
done

echo ""

if [[ "$WAIT" == true ]]; then
  echo "Waiting for commands to complete..."
  echo ""

  for src in "${SOURCES[@]}"; do
    cmd_id="${COMMAND_IDS[$src]:-}"
    if [[ -z "$cmd_id" ]]; then
      echo "  [$src] SKIPPED (no command ID)"
      continue
    fi

    echo -n "  [$src] Waiting..."
    # Poll for completion (max 1 hour)
    for i in $(seq 1 720); do
      status=$(aws ssm get-command-invocation \
        --command-id "$cmd_id" \
        --instance-id "$INSTANCE_ID" \
        --query "Status" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "Pending")

      if [[ "$status" == "Success" ]]; then
        echo " SUCCESS"
        # Show last 3 lines of output
        aws ssm get-command-invocation \
          --command-id "$cmd_id" \
          --instance-id "$INSTANCE_ID" \
          --query "StandardOutputContent" \
          --output text \
          --region "$REGION" 2>/dev/null | tail -3 | sed 's/^/    /'
        break
      elif [[ "$status" == "Failed" || "$status" == "TimedOut" || "$status" == "Cancelled" ]]; then
        echo " $status"
        aws ssm get-command-invocation \
          --command-id "$cmd_id" \
          --instance-id "$INSTANCE_ID" \
          --query "StandardErrorContent" \
          --output text \
          --region "$REGION" 2>/dev/null | tail -5 | sed 's/^/    /'
        break
      fi

      if [[ $i -eq 720 ]]; then
        echo " TIMEOUT (still running after 1 hour)"
        break
      fi
      sleep 5
    done
  done
else
  echo "Commands sent. To check status:"
  for src in "${SOURCES[@]}"; do
    cmd_id="${COMMAND_IDS[$src]:-}"
    if [[ -n "$cmd_id" ]]; then
      echo "  $src: aws ssm get-command-invocation --command-id $cmd_id --instance-id $INSTANCE_ID --region $REGION --query '{Status:Status,Output:StandardOutputContent}'"
    fi
  done
  echo ""
  echo "Or re-run with --wait flag: make generate-data args=\"--wait\""
fi
