#!/bin/bash
# Script to add inline IAM group policy for specific S3 bucket or prefix
# Supports tenant-aware resource ARNs for CEPH S3 storage

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <group-name> <bucket-name> [prefix] [tenant] [access-level]"
    echo ""
    echo "Arguments:"
    echo "  group-name   - IAM group name"
    echo "  bucket-name  - S3 bucket name"
    echo "  prefix       - Optional: S3 prefix/folder path (e.g., 'data/' or 'users/john/')"
    echo "  tenant       - Optional: CEPH tenant (default: \$AWS_DEFAULT_TENANT or sils_mns)"
    echo "  access-level - Optional: 'read', 'write', or 'full' (default: full)"
    echo ""
    echo "Access Levels:"
    echo "  read  - GetObject, ListBucket"
    echo "  write - PutObject, DeleteObject (includes read)"
    echo "  full  - All S3 operations (default)"
    echo ""
    echo "Note: This script always uses the 'default' AWS profile for IAM operations."
    echo ""
    echo "Examples:"
    echo "  # Full access to entire bucket"
    echo "  $0 developers project-data"
    echo ""
    echo "  # Full access to specific prefix in bucket"
    echo "  $0 researchers shared-data experiments/"
    echo ""
    echo "  # Read-only access to entire bucket with default tenant"
    echo "  $0 mns_pi groups \"\" \"\" read"
    echo ""
    echo "  # Read-only access to prefix with custom tenant"
    echo "  $0 analysts data-bucket reports/ project_alpha read"
    echo ""
    echo "  # Write access (read+write) to specific folder"
    echo "  $0 editors content uploads/ sils_mns write"
    exit 1
fi

GROUP_NAME="$1"
BUCKET_NAME="$2"
PREFIX="${3:-}"
TENANT="${4:-${AWS_DEFAULT_TENANT:-sils_mns}}"
ACCESS_LEVEL="${5:-full}"

# Normalize prefix - ensure it ends with / if provided and not empty
if [ -n "$PREFIX" ] && [[ ! "$PREFIX" =~ /$ ]]; then
    PREFIX="${PREFIX}/"
fi

# Save original profile and force use of default for IAM operations
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

# Generate policy name based on bucket and prefix
if [ -n "$PREFIX" ]; then
    # Sanitize prefix for policy name (replace / with -)
    PREFIX_CLEAN=$(echo "$PREFIX" | sed 's/\/$//; s/\//-/g')
    POLICY_NAME="s3-${BUCKET_NAME}-${PREFIX_CLEAN}"
else
    POLICY_NAME="s3-${BUCKET_NAME}-full"
fi

# Define actions based on access level
case "$ACCESS_LEVEL" in
    read)
        ACTIONS='
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket",
        "s3:ListBucketVersions"'
        ;;
    write)
        ACTIONS='
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:ListBucketVersions"'
        ;;
    full)
        ACTIONS='
        "s3:*"'
        ;;
    *)
        echo "✗ Invalid access level: $ACCESS_LEVEL"
        echo "  Must be 'read', 'write', or 'full'"
        exit 1
        ;;
esac

# Build resource ARNs with tenant
if [ -n "$PREFIX" ]; then
    # Prefix-specific policy
    RESOURCES="
        \"arn:aws:s3::${TENANT}:${BUCKET_NAME}\",
        \"arn:aws:s3::${TENANT}:${BUCKET_NAME}/${PREFIX}*\""
    RESOURCE_DESC="bucket '$BUCKET_NAME' prefix '$PREFIX'"
else
    # Bucket-wide policy
    RESOURCES="
        \"arn:aws:s3::${TENANT}:${BUCKET_NAME}\",
        \"arn:aws:s3::${TENANT}:${BUCKET_NAME}/*\""
    RESOURCE_DESC="bucket '$BUCKET_NAME'"
fi

# Create policy document
POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [${ACTIONS}
      ],
      "Resource": [${RESOURCES}
      ]
    }
  ]
}
EOF
)

echo "Adding S3 bucket policy to group: $GROUP_NAME"
echo "Bucket: $BUCKET_NAME"
[ -n "$PREFIX" ] && echo "Prefix: $PREFIX"
echo "Tenant: $TENANT"
echo "Access Level: $ACCESS_LEVEL"
echo "Policy Name: $POLICY_NAME"
echo ""

# Check if group exists
if ! aws iam get-group --group-name "$GROUP_NAME" &>/dev/null; then
    echo "✗ Group '$GROUP_NAME' does not exist"
    echo "  Create it first with: aws-create-group $GROUP_NAME"
    exit 1
fi

# Apply the policy
if aws iam put-group-policy \
    --group-name "$GROUP_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOCUMENT"; then
    echo ""
    echo "✓ Policy '$POLICY_NAME' applied to group '$GROUP_NAME'"
    echo "  Access: $ACCESS_LEVEL"
    echo "  Resource: $RESOURCE_DESC"
    echo "  Tenant: $TENANT"
else
    echo ""
    echo "✗ Failed to apply policy to group"
    exit 1
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
