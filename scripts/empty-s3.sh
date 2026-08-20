#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Empty an S3 bucket including all object versions and delete markers.
#
# Usage:
#   ./scripts/empty-s3.sh empty_s3_bucket_by_name <bucket-name>

set -euo pipefail

# Delete all versioned objects and delete markers from an S3 bucket.
# $1 — the S3 bucket name
delete_versioned_files() {
    local bucket="$1"

    echo "  Deleting all object versions..."

    local versions
    versions=$(aws s3api list-object-versions --bucket "$bucket" --query 'Versions' --output json 2>/dev/null || echo "null")

    if [[ "$versions" != "null" && "$versions" != "[]" ]]; then
        local count
        count=$(echo "$versions" | jq 'length')
        echo "    Version count: $count"

        echo "$versions" | jq -c '.[]' | while IFS= read -r obj; do
            local key versionId
            key=$(echo "$obj" | jq -r '.Key')
            versionId=$(echo "$obj" | jq -r '.VersionId')
            aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$versionId" > /dev/null
        done
    else
        echo "    No object versions found."
    fi

    local markers
    markers=$(aws s3api list-object-versions --bucket "$bucket" --query 'DeleteMarkers' --output json 2>/dev/null || echo "null")

    if [[ "$markers" != "null" && "$markers" != "[]" ]]; then
        local count
        count=$(echo "$markers" | jq 'length')
        echo "    Delete marker count: $count"

        echo "$markers" | jq -c '.[]' | while IFS= read -r obj; do
            local key versionId
            key=$(echo "$obj" | jq -r '.Key')
            versionId=$(echo "$obj" | jq -r '.VersionId')
            aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$versionId" > /dev/null
        done
    else
        echo "    No delete markers found."
    fi

    echo "  Finished deleting all object versions."
}

# Empty the supplied S3 bucket, including all file versions.
# $1 — bucket name
empty_s3_bucket_by_name() {
    local bucket="${1:?ERROR: bucket name must be supplied as the first argument}"

    echo ""
    echo "Checking if bucket \"$bucket\" exists..."
    if ! aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
        echo "  Bucket \"$bucket\" does not exist — skipping."
        return 0
    fi
    echo "  Bucket exists."

    echo ""
    echo "Emptying S3 bucket: \"$bucket\"..."
    echo "  Deleting all non-versioned objects..."
    aws s3 rm "s3://$bucket" --recursive --quiet || true

    delete_versioned_files "$bucket"

    echo ""
    echo "Finished emptying S3 bucket: \"$bucket\""
}

# Dispatch: call the function named by the first argument
if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <function-name> [args...]" >&2
    echo "Available functions: empty_s3_bucket_by_name" >&2
    exit 1
else
    "$@"
fi
