#!/bin/bash
# AWS Get Bucket Policy Script
# Usage: ./aws-get-bucket-policy.sh <bucket-name>

BUCKET_NAME="$1"

if [ -z "$BUCKET_NAME" ]; then
    echo "Usage: $0 <bucket-name>"
    echo "  bucket-name: Name of the S3 bucket"
    exit 1
fi

# Save current profile and use default for operations
ORIG_AWS_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

echo "Getting policy for bucket: $BUCKET_NAME"
echo ""

# Get the bucket policy
POLICY=$(aws s3api get-bucket-policy --bucket "$BUCKET_NAME" --query Policy --output text 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    # Format JSON output nicely if jq is available
    if command -v jq &> /dev/null; then
        echo "$POLICY" | jq '.'
    else
        echo "$POLICY"
    fi
else
    # Check if it's a "no policy" error
    if echo "$POLICY" | grep -q "NoSuchBucketPolicy"; then
        echo "No bucket policy is set for bucket '$BUCKET_NAME'"
    else
        echo "Error getting bucket policy:"
        echo "$POLICY"
    fi
fi

# Restore original profile
if [ -n "$ORIG_AWS_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_AWS_PROFILE"
else
    unset AWS_PROFILE
fi
