#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
# scripts/deploy-tf-backend.sh — Deploy CloudFormation stack for Terraform S3 backend
#
# Creates an S3 bucket (versioned, encrypted) and KMS key used for Terraform state.
# The stack name and bucket name are derived from APP_NAME and ENV_NAME.
#
# Usage: scripts/deploy-tf-backend.sh [destroy]
#
# Required env vars (loaded from .env if present): APP_NAME, ENV_NAME

set -euo pipefail

ACTION="${1:-deploy}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOTSTRAP_DIR="$REPO_ROOT/iac/bootstrap"

if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$REPO_ROOT/.env"
  set +a
fi

: "${APP_NAME:?APP_NAME is required (set in .env)}"
: "${ENV_NAME:?ENV_NAME is required (set in .env)}"
: "${AWS_PRIMARY_REGION:=us-east-1}"
: "${AWS_DEFAULT_REGION:=$AWS_PRIMARY_REGION}"
: "${TF_S3_BACKEND_NAME:=${APP_NAME}-${ENV_NAME}-tf-back-end}"

if [[ "$ACTION" == "destroy" ]]; then
  echo "Destroying CloudFormation stack: $TF_S3_BACKEND_NAME"
  aws cloudformation delete-stack \
    --stack-name "$TF_S3_BACKEND_NAME" \
    --region "$AWS_DEFAULT_REGION"
  aws cloudformation wait stack-delete-complete \
    --stack-name "$TF_S3_BACKEND_NAME" \
    --region "$AWS_DEFAULT_REGION" || true
  echo "Stack destroyed."
  exit 0
fi

PARAMS_FILE="$BOOTSTRAP_DIR/parameters.json"
PARAMS_BAK="${PARAMS_FILE}.bak"

cleanup() {
  [[ -f "$PARAMS_BAK" ]] && mv "$PARAMS_BAK" "$PARAMS_FILE"
}
trap cleanup EXIT

cp "$PARAMS_FILE" "$PARAMS_BAK"
sed -i.tmp -e "s|###TF_S3_BACKEND_NAME###|${TF_S3_BACKEND_NAME}|g" "$PARAMS_FILE"
rm -f "${PARAMS_FILE}.tmp"

# Convert ["k=v","k=v"] JSON array to space-separated k=v pairs for --parameter-overrides
PARAM_OVERRIDES=$(jq -r '.[]' "$PARAMS_FILE" | tr '\n' ' ')

echo "Deploying CloudFormation stack: $TF_S3_BACKEND_NAME"
echo "  Region: $AWS_DEFAULT_REGION"
echo "  Parameters: $PARAM_OVERRIDES"

# shellcheck disable=SC2086
aws cloudformation deploy \
  --template-file "$BOOTSTRAP_DIR/tf-backend-cf-stack.yml" \
  --stack-name "$TF_S3_BACKEND_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$AWS_DEFAULT_REGION" \
  --parameter-overrides $PARAM_OVERRIDES

echo "Stack deployed successfully."
