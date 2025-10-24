#!/bin/bash
# Script to replace broad S3 policies with bucket-specific access for a group

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <group-name> <bucket-name> [access-level] [profile]"
    echo ""
    echo "Arguments:"
    echo "  group-name    - IAM group name"
    echo "  bucket-name   - S3 bucket name"
    echo "  access-level  - Optional: full, read, write (default: read)"
    echo "  profile       - Optional: AWS profile to use (default: default)"
    echo ""
    echo "This script will:"
    echo "  1. Remove broad S3 policies (AmazonS3FullAccess, AmazonS3ReadOnlyAccess)"
    echo "  2. Attach bucket-specific policy for the specified bucket"
    echo ""
    echo "Examples:"
    echo "  $0 sub-users bda-test-data read"
    echo "  $0 developers my-bucket full"
    exit 1
fi

GROUP_NAME="$1"
BUCKET_NAME="$2"
ACCESS_LEVEL="${3:-read}"
PROFILE="${4:-default}"

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

echo "Restricting group '$GROUP_NAME' to bucket: $BUCKET_NAME"
echo "Access level: $ACCESS_LEVEL"
echo ""

# Define broad S3 policies to remove
BROAD_POLICIES=(
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
)

# Check and remove broad S3 policies
echo "Step 1: Checking for broad S3 policies..."
REMOVED_ANY=0

for POLICY_ARN in "${BROAD_POLICIES[@]}"; do
    # Check if policy is attached
    if aws iam list-attached-group-policies --group-name "$GROUP_NAME" --output json 2>/dev/null | jq -e ".AttachedPolicies[] | select(.PolicyArn == \"$POLICY_ARN\")" > /dev/null; then
        POLICY_NAME=$(basename "$POLICY_ARN")
        echo "  - Removing: $POLICY_NAME"
        aws iam detach-group-policy --group-name "$GROUP_NAME" --policy-arn "$POLICY_ARN"
        REMOVED_ANY=1
    fi
done

if [ $REMOVED_ANY -eq 0 ]; then
    echo "  No broad S3 policies found"
fi

echo ""
echo "Step 2: Attaching bucket-specific policy..."

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

# Apply the bucket-specific policy
if aws iam put-group-policy \
    --group-name "$GROUP_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOCUMENT"; then
    echo "  ✓ Policy '$POLICY_NAME' attached"
else
    echo "  ✗ Failed to attach bucket-specific policy"
    exit 1
fi

echo ""
echo "✓ Group '$GROUP_NAME' now has $ACCESS_LEVEL access ONLY to bucket: $BUCKET_NAME"
echo ""
echo "Summary:"
echo "  - Removed broad S3 access policies"
echo "  - Added bucket-specific policy: $POLICY_NAME"
echo "  - Members can now access only: $BUCKET_NAME"

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
