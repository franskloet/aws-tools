#!/bin/bash
# Script to delete bucket policy

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <bucket-name> [profile]"
    echo ""
    echo "Arguments:"
    echo "  bucket-name - S3 bucket name"
    echo "  profile     - Optional: AWS profile to use (default: default)"
    echo ""
    echo "WARNING: This will remove the bucket policy, reverting to IAM-only access control"
    echo ""
    echo "Examples:"
    echo "  $0 bda-test-bucket"
    echo "  $0 my-bucket myprofile"
    exit 1
fi

BUCKET_NAME="$1"
PROFILE="${2:-default}"

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

echo "Deleting bucket policy for: $BUCKET_NAME"
echo ""

# Check if bucket policy exists
if aws s3api get-bucket-policy --bucket "$BUCKET_NAME" 2>/dev/null >/dev/null; then
    echo "Current bucket policy found"
    echo ""
    
    # Delete the bucket policy
    if aws s3api delete-bucket-policy --bucket "$BUCKET_NAME"; then
        echo ""
        echo "✓ Bucket policy deleted for: $BUCKET_NAME"
        echo ""
        echo "Note: Access is now controlled by IAM policies only"
    else
        echo ""
        echo "✗ Failed to delete bucket policy"
        exit 1
    fi
else
    echo "No bucket policy found for: $BUCKET_NAME"
    echo "Nothing to delete"
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
