#!/bin/bash
# Wrapper for aws s3api create-bucket
# Simplified bucket creation with optional ACL support

if [ -z "$1" ]; then
    echo "Usage: $0 <bucket-name> [acl]"
    echo ""
    echo "Arguments:"
    echo "  bucket-name - Name of the bucket to create"
    echo "  acl         - Optional: ACL (default: private)"
    echo "                Options: private, public-read, public-read-write, authenticated-read"
    echo ""
    echo "Examples:"
    echo "  $0 my-bucket"
    echo "  $0 public-data public-read"
    exit 1
fi

BUCKET_NAME="$1"
ACL="${2:-private}"

echo "Creating bucket: $BUCKET_NAME"
echo "ACL: $ACL"
echo ""

OUTPUT=$(aws s3api create-bucket --bucket "$BUCKET_NAME" --acl "$ACL" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✓ Bucket '$BUCKET_NAME' created successfully"
else
    echo ""
    if [[ "$OUTPUT" == *"argument of type 'NoneType' is not iterable"* ]]; then
        echo "✗ Access denied: You do not have permission to create buckets"
    else
        echo "✗ Failed to create bucket '$BUCKET_NAME'"
        echo "$OUTPUT"
    fi
    exit 1
fi
