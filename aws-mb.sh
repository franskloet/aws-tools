#!/bin/bash
# Wrapper for aws s3api create-bucket
# Simplified bucket creation with optional ACL support

if [ -z "$1" ]; then
    echo "Usage: $0 <bucket-name> [acl] [region]"
    echo ""
    echo "Arguments:"
    echo "  bucket-name - Name of the bucket to create"
    echo "  acl         - Optional: ACL (default: private)"
    echo "                Options: private, public-read, public-read-write, authenticated-read"
    echo "  region      - Optional: AWS region (default: from AWS config or us-east-1)"
    echo ""
    echo "Examples:"
    echo "  $0 my-bucket"
    echo "  $0 public-data public-read"
    echo "  $0 my-bucket private eu-west-1"
    exit 1
fi

BUCKET_NAME="$1"
ACL="${2:-private}"
REGION="${3:-$(aws configure get region 2>/dev/null || echo 'us-east-1')}"

echo "Creating bucket: $BUCKET_NAME"
echo "ACL: $ACL"
echo "Region: $REGION"
echo ""

# For us-east-1, don't specify LocationConstraint
if [ "$REGION" = "us-east-1" ]; then
    OUTPUT=$(aws s3api create-bucket --bucket "$BUCKET_NAME" --acl "$ACL" --region "$REGION" 2>&1)
    EXIT_CODE=$?
else
    OUTPUT=$(aws s3api create-bucket --bucket "$BUCKET_NAME" --acl "$ACL" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION" 2>&1)
    EXIT_CODE=$?
fi

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
