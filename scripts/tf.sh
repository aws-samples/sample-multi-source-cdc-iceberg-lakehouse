#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
# scripts/tf.sh — Run terraform on a module with ###PLACEHOLDER### substitution
#
# Usage:
#   scripts/tf.sh <module-path-under-iac/roots> [extra-terraform-args...]
#
# Examples:
#   scripts/tf.sh foundation/iam-roles
#   scripts/tf.sh foundation/iam-roles -target=aws_iam_role.foo
#   TF_MODE=destroy scripts/tf.sh foundation/iam-roles
#
# Required env vars (loaded from .env if present):
#   APP_NAME, ENV_NAME, AWS_ACCOUNT_ID
#
# Optional env vars (with defaults):
#   AWS_PRIMARY_REGION    (default: us-east-1)
#   AWS_DEFAULT_REGION    (default: $AWS_PRIMARY_REGION)
#   TF_S3_BACKEND_NAME    (default: ${APP_NAME}-${ENV_NAME}-tf-back-end)
#   TF_MODE               (default: apply; supports apply, destroy, plan, validate)

set -euo pipefail

MODULE="${1:-}"
if [[ -z "$MODULE" ]]; then
  echo "Usage: $0 <module-path-under-iac/roots> [tf-args...]" >&2
  exit 1
fi
shift

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODULE_DIR="$REPO_ROOT/iac/roots/$MODULE"

if [[ ! -d "$MODULE_DIR" ]]; then
  echo "Module directory not found: $MODULE_DIR" >&2
  exit 1
fi

# Load .env if present
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$REPO_ROOT/.env"
  set +a
fi

# Required vars
: "${APP_NAME:?APP_NAME is required (set in .env)}"
: "${ENV_NAME:?ENV_NAME is required (set in .env)}"
: "${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID is required (set in .env)}"

# Defaults
: "${AWS_PRIMARY_REGION:=us-east-1}"
: "${AWS_DEFAULT_REGION:=$AWS_PRIMARY_REGION}"
: "${TF_S3_BACKEND_NAME:=${APP_NAME}-${ENV_NAME}-tf-back-end}"
: "${TF_MODE:=apply}"

export APP_NAME ENV_NAME AWS_ACCOUNT_ID
export AWS_PRIMARY_REGION AWS_DEFAULT_REGION
export TF_S3_BACKEND_NAME

# Special placeholder: relative module path under iac/roots/ (used in backend.tf state keys)
CUR_DIR_NAME="$MODULE"

# Discover files containing ###PLACEHOLDER### patterns
TEMPLATE_FILES=()
while IFS= read -r f; do
  TEMPLATE_FILES+=("$f")
done < <(grep -rlE '###[A-Z_][A-Z0-9_]*###' "$MODULE_DIR" 2>/dev/null || true)

restore_files() {
  for f in "${TEMPLATE_FILES[@]:-}"; do
    [[ -f "${f}.bak" ]] && mv "${f}.bak" "$f"
  done
}
trap restore_files EXIT

# Ported as-is from main's environment/bash-5-utils.sh (display -> echo).
# Cleans up zombie Firehose delivery streams left in a failed state so the
# retry can recreate them, and drops any partial Firehose state.
_cleanup_failed_firehose_streams () {
    local stderr_file="$1"
    local region="${AWS_PRIMARY_REGION:-us-east-1}"

    # Extract Firehose stream names from error output
    # Matches patterns like: "Firehose <name> under accountId" or "Delivery Stream (<name>)"
    local stream_names
    stream_names=$(grep -oEi 'Firehose [a-zA-Z0-9_-]+ under|Delivery Stream \([a-zA-Z0-9_-]+\)' "$stderr_file" \
        | sed -E 's/Firehose ([a-zA-Z0-9_-]+) under/\1/; s/Delivery Stream \(([a-zA-Z0-9_-]+)\)/\1/' \
        | sort -u)

    if [ -z "$stream_names" ]; then
        echo "  No Firehose stream names found in error output. Skipping cleanup."
        return 0
    fi

    # Track ONLY the streams we actually delete from AWS. We must never remove an
    # ACTIVE stream from Terraform state: doing so orphans a live resource (gone from
    # state, still in AWS), and the very next retry fails with
    # "ResourceInUseException: ... already exists". Only streams that were genuinely
    # deleted from AWS should be dropped from state so the retry can recreate them.
    local deleted_streams=()

    for stream_name in $stream_names; do
        local status
        status=$(aws firehose describe-delivery-stream \
            --delivery-stream-name "$stream_name" \
            --query 'DeliveryStreamDescription.DeliveryStreamStatus' \
            --output text \
            --region "$region" 2>/dev/null) || continue

        if [[ "$status" == "CREATING_FAILED" || "$status" == "DELETING_FAILED" ]]; then
            echo "  Deleting zombie Firehose stream '$stream_name' (status: $status)..."
            aws firehose delete-delivery-stream \
                --delivery-stream-name "$stream_name" \
                --allow-force-delete \
                --region "$region" 2>/dev/null || true

            # Wait for deletion (max 60s)
            local waited=0
            local confirmed_deleted=false
            while [ $waited -lt 60 ]; do
                if ! aws firehose describe-delivery-stream \
                    --delivery-stream-name "$stream_name" \
                    --region "$region" 2>/dev/null >/dev/null; then
                    echo "  Zombie stream '$stream_name' deleted successfully."
                    confirmed_deleted=true
                    break
                fi
                sleep 5
                waited=$((waited + 5))
            done
            if [ "$confirmed_deleted" = true ]; then
                deleted_streams+=("$stream_name")
            fi
        else
            echo "  Firehose stream '$stream_name' is '$status' (not a failed zombie) — leaving it in AWS and Terraform state untouched."
        fi
    done

    # Drop ONLY the streams we confirmed-deleted above from Terraform state, so the
    # retry recreates exactly those. Match each state address to its real stream name
    # (via the resource's 'name' attribute) instead of blanket-removing every stream.
    if [ ${#deleted_streams[@]} -eq 0 ]; then
        return 0
    fi
    local state_addresses
    state_addresses=$(terraform state list 2>/dev/null | grep 'aws_kinesis_firehose_delivery_stream\.delivery_stream' || true)
    for addr in $state_addresses; do
        local addr_name
        addr_name=$(terraform state show "$addr" 2>/dev/null | grep -oE 'name[[:space:]]*=[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
        for del in "${deleted_streams[@]}"; do
            if [ "$addr_name" = "$del" ]; then
                echo "  Removing '$addr' (stream '$addr_name') from Terraform state for clean re-creation..."
                terraform state rm "$addr" 2>/dev/null || true
                break
            fi
        done
    done
}

# Back up template files, then substitute placeholders
for f in "${TEMPLATE_FILES[@]:-}"; do
  cp "$f" "${f}.bak"
  sed -i.tmp \
    -e "s|###APP_NAME###|${APP_NAME}|g" \
    -e "s|###ENV_NAME###|${ENV_NAME}|g" \
    -e "s|###AWS_ACCOUNT_ID###|${AWS_ACCOUNT_ID}|g" \
    -e "s|###AWS_PRIMARY_REGION###|${AWS_PRIMARY_REGION}|g" \
    -e "s|###AWS_DEFAULT_REGION###|${AWS_DEFAULT_REGION}|g" \
    -e "s|###TF_S3_BACKEND_NAME###|${TF_S3_BACKEND_NAME}|g" \
    -e "s|###CUR_DIR_NAME###|${CUR_DIR_NAME}|g" \
    "$f"
  rm -f "${f}.tmp"
done

cd "$MODULE_DIR"
terraform init -input=false

# stderr capture file for the retry loop (as in main's exec_tf_for_env)
tf_stderr_file=$(mktemp "${TMPDIR:-/tmp}/tf-stderr.XXXXXX")
trap 'rm -f "$tf_stderr_file"; restore_files' EXIT

# -auto-approve is only valid for apply/destroy.
# Retry loop ported AS-IS from main's environment/bash-5-utils.sh exec_tf_for_env
# (display/displayIssue -> echo). 3 attempts, 30s delay, retries only on known
# transient network errors and Firehose PrivateLink/creation failures; any other
# error fails immediately.
if [[ "$TF_MODE" == "apply" ]] || [[ "$TF_MODE" == "destroy" ]]; then
    max_retries=3
    retry_delay=30
    # Fresh-account EC2 gate (PendingVerification) can take "minutes" per AWS — give that
    # specific error class a much longer budget than the 3x30s network/Firehose retries.
    gate_max_retries=10
    gate_delay=60
    effective_max=$max_retries
    attempt=1
    iacExitCode=0

    while [ $attempt -le $effective_max ]; do
        if [ $attempt -gt 1 ]; then
            echo "⟳ Retry attempt $attempt of $effective_max for terraform $TF_MODE (waiting ${retry_delay}s)..."
            sleep $retry_delay
        fi

        set +e
        terraform "$TF_MODE" -auto-approve -input=false "$@" 2> >(tee "$tf_stderr_file" >&2) # nosemgrep
        iacExitCode=$?
        set -e

        if [ $iacExitCode -eq 0 ]; then
            break
        fi

        # Retry on known transient network errors
        if grep -qEi "dial tcp.*no such host|TLS handshake timeout|connection reset by peer|Client\.Timeout exceeded|tcp.*timeout|net/http.*TLS.*timeout" "$tf_stderr_file"; then
            echo "⚠ Transient network error detected during terraform $TF_MODE (attempt $attempt of $effective_max)."
        # Retry on go-plugin handshake failures — the provider subprocess failed to
        # negotiate its handshake before the timeout (typically transient host
        # memory/IO pressure stalling the 800MB+ provider launch, NOT a corrupt or
        # wrong-arch binary). A short delay + relaunch almost always succeeds.
        elif grep -qEi "Failed to load plugin schemas|Unrecognized remote plugin message|Failed to read any lines from plugin|failed to negotiate the initial go-plugin|failed to instantiate provider.*to obtain schema" "$tf_stderr_file"; then
            echo "⚠ Provider plugin handshake failure detected (attempt $attempt of $effective_max) — likely host resource pressure; relaunching after ${retry_delay}s."
        # Retry on Firehose transient PrivateLink/creation failures — clean up zombie streams first
        elif grep -qEi "CREATE_PRIVATE_LINK_FAILED|CREATING_FAILED|ResourceInUseException.*Firehose" "$tf_stderr_file"; then
            echo "⚠ Firehose transient creation failure detected (attempt $attempt of $effective_max). Cleaning up zombie streams..."
            _cleanup_failed_firehose_streams "$tf_stderr_file"
        # Retry on fresh-account EC2 verification gate — uses the longer budget above
        elif grep -qEi "PendingVerification|OptInRequired" "$tf_stderr_file"; then
            effective_max=$gate_max_retries
            retry_delay=$gate_delay
            echo "⚠ Fresh-account verification gate (PendingVerification) detected (attempt $attempt of $effective_max) — AWS is validating the account; retrying with ${retry_delay}s delay."
        else
            # Not a transient error — fail immediately
            break
        fi

        attempt=$((attempt + 1))
    done

    if [ $iacExitCode -ne 0 ] && [ $attempt -gt $effective_max ]; then
        echo "✖ terraform $TF_MODE failed after $effective_max attempts due to transient errors." >&2
    fi
    exit $iacExitCode
else
    terraform "$TF_MODE" -input=false "$@"
fi
