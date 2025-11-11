#!/bin/bash
# Script to create IAM user policy for CEPH S3 storage
# Limits access to specific buckets and/or prefixes with tenant support

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <username> <bucket-name> [prefix1] [prefix2] ... [tenant=<tenant>]"
    echo ""
    echo "Arguments:"
    echo "  username    - IAM username"
    echo "  bucket-name - S3 bucket name"
    echo "  prefix1,2.. - Optional: specific prefixes within the bucket"
    echo "  tenant=...  - Optional: CEPH tenant (default: sils_mns)"
    echo ""
    echo "This creates an inline policy that grants the user:"
    echo "  - ListBucket permission for the specified bucket"
    echo "  - Full object access (Get, Put, Delete) for specified prefixes or entire bucket"
    echo ""
    echo "Note: This script always uses the 'default' AWS profile for IAM operations."
    echo ""
    echo "Examples:"
    echo "  # Full access to bucket"
    echo "  $0 john users"
    echo ""
    echo "  # Access to specific prefixes in bucket"
    echo "  $0 alice data project1/ shared/"
    echo ""
    echo "  # With custom tenant"
    echo "  $0 bob research experiment1/ tenant=project_alpha"
    exit 1
fi

USERNAME="$1"
BUCKET_NAME="$2"
shift 2

# Default tenant
TENANT="sils_mns"
PREFIXES=()

# Parse remaining arguments
for arg in "$@"; do
    if [[ "$arg" == tenant=* ]]; then
        TENANT="${arg#tenant=}"
    else
        PREFIXES+=("$arg")
    fi
done

# Save original profile and force use of default for IAM operations
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

POLICY_NAME="${USERNAME}-${BUCKET_NAME}-access"

# Build Resource ARNs based on prefixes
if [ ${#PREFIXES[@]} -eq 0 ]; then
    # No prefixes specified - grant access to entire bucket
    LIST_RESOURCE="\"arn:aws:s3::${TENANT}:${BUCKET_NAME}\""
    OBJECT_RESOURCES="\"arn:aws:s3::${TENANT}:${BUCKET_NAME}/*\""
    PREFIX_DESC="entire bucket"
else
    # Specific prefixes - grant access only to those prefixes
    LIST_RESOURCE="\"arn:aws:s3::${TENANT}:${BUCKET_NAME}\""
    OBJECT_RESOURCES_ARRAY=()
    PREFIX_DESC="prefixes: ${PREFIXES[*]}"
    
    for prefix in "${PREFIXES[@]}"; do
        # Remove trailing slash if present, we'll add it
        prefix="${prefix%/}"
        OBJECT_RESOURCES_ARRAY+=("\"arn:aws:s3::${TENANT}:${BUCKET_NAME}/${prefix}/*\"")
    done
    
    # Join array elements with comma and newline
    OBJECT_RESOURCES=$(printf ",\n        %s" "${OBJECT_RESOURCES_ARRAY[@]}")
    OBJECT_RESOURCES=${OBJECT_RESOURCES:1}  # Remove leading comma
fi

# Create policy document
POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        ${LIST_RESOURCE}
      ]
    },
    {
      "Sid": "AllowObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        ${OBJECT_RESOURCES}
      ]
    }
  ]
}
EOF
)

echo "Creating bucket access policy for user: $USERNAME"
echo "Tenant: $TENANT"
echo "Bucket: $BUCKET_NAME"
echo "Access: $PREFIX_DESC"
echo ""

# Check if user exists
if ! aws iam get-user --user-name "$USERNAME" &>/dev/null; then
    echo "✗ User '$USERNAME' does not exist"
    echo "  Create it first with: aws-create-user $USERNAME"
    exit 1
fi

# Apply the policy
if aws iam put-user-policy \
    --user-name "$USERNAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOCUMENT"; then
    echo ""
    echo "✓ Policy '$POLICY_NAME' applied to user '$USERNAME'"
    echo "  User has access to: s3://$BUCKET_NAME/"
    if [ ${#PREFIXES[@]} -gt 0 ]; then
        for prefix in "${PREFIXES[@]}"; do
            echo "    - ${prefix%/}/"
        done
    fi
else
    echo ""
    echo "✗ Failed to apply policy to user"
    exit 1
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
