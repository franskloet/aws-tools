#!/bin/bash
# Script to attach IAM policy to group for specific S3 bucket access

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <group-name> <bucket-name> [access-level]"
    echo ""
    echo "Arguments:"
    echo "  group-name    - IAM group name"
    echo "  bucket-name   - S3 bucket name"
    echo "  access-level  - Optional: full, read, write (default: full)"
    echo ""
    echo "Note: This script always uses the 'default' AWS profile for IAM operations."
    echo ""
    echo "Examples:"
    echo "  $0 data-scientists my-bucket"
    echo "  $0 analysts my-bucket read"
    echo "  $0 developers my-bucket write"
    exit 1
fi

GROUP_NAME="$1"
BUCKET_NAME="$2"
ACCESS_LEVEL="${3:-full}"

# Save original profile and force use of default for IAM operations
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

# Define policy based on access level
case "$ACCESS_LEVEL" in
    full)
        ACTIONS='"s3:*"'
        ;;
    read)
        ACTIONS='"s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"'
        ;;
    write)
        ACTIONS='"s3:PutObject", "s3:PutObjectAcl", "s3:DeleteObject"'
        ;;
    *)
        echo "Error: Invalid access level. Use: full, read, or write"
        exit 1
        ;;
esac

# Create policy document
POLICY_NAME="${GROUP_NAME}-${BUCKET_NAME}-${ACCESS_LEVEL}"
POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [$ACTIONS],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF
)

echo "Attaching policy to group: $GROUP_NAME"
echo "Bucket: $BUCKET_NAME"
echo "Access level: $ACCESS_LEVEL"
echo ""

# Apply the policy
if aws iam put-group-policy \
    --group-name "$GROUP_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOCUMENT"; then
    echo ""
    echo "✓ Policy '$POLICY_NAME' attached to group '$GROUP_NAME'"
    echo "  Members of this group now have $ACCESS_LEVEL access to bucket: $BUCKET_NAME"
else
    echo ""
    echo "✗ Failed to attach policy to group"
    exit 1
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
