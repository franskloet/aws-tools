#!/bin/bash
# Script to delete inline IAM policy from group for specific S3 bucket access

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <group-name> <bucket-name> [access-level] [profile]"
    echo ""
    echo "Arguments:"
    echo "  group-name    - IAM group name"
    echo "  bucket-name   - S3 bucket name"
    echo "  access-level  - Optional: full, read, write (default: full)"
    echo "  profile       - Optional: AWS profile to use (default: default)"
    echo ""
    echo "Note: This removes the inline policy created by aws-attach-group-bucket-policy"
    echo ""
    echo "Examples:"
    echo "  $0 data-scientists my-bucket"
    echo "  $0 analysts my-bucket read"
    echo "  $0 developers my-bucket full myprofile"
    exit 1
fi

GROUP_NAME="$1"
BUCKET_NAME="$2"
ACCESS_LEVEL="${3:-full}"
PROFILE="${4:-default}"

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

# Construct policy name (same format as attach script)
POLICY_NAME="${GROUP_NAME}-${BUCKET_NAME}-${ACCESS_LEVEL}"

echo "Removing inline policy from group: $GROUP_NAME"
echo "Policy name: $POLICY_NAME"
echo ""

# Delete the inline policy
if aws iam delete-group-policy \
    --group-name "$GROUP_NAME" \
    --policy-name "$POLICY_NAME"; then
    echo ""
    echo "✓ Policy '$POLICY_NAME' removed from group '$GROUP_NAME'"
    echo "  Members of this group no longer have $ACCESS_LEVEL access to bucket: $BUCKET_NAME"
else
    echo ""
    echo "✗ Failed to remove policy from group"
    echo "  Hint: Use 'aws iam list-group-policies --group-name $GROUP_NAME' to see available policies"
    exit 1
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
