#!/bin/bash
# Script to create IAM group policy for CEPH S3 storage
# Applies a default S3 access policy to a group with tenant support

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <group-name> [tenant]"
    echo ""
    echo "Arguments:"
    echo "  group-name - IAM group name"
    echo "  tenant     - Optional: CEPH tenant (default: \$AWS_DEFAULT_TENANT or sils_mns)"
    echo ""
    echo "This creates an inline policy that grants the group:"
    echo "  - ListAllMyBuckets permission for the tenant"
    echo ""
    echo "Note: This script always uses the 'default' AWS profile for IAM operations."
    echo ""
    echo "Examples:"
    echo "  $0 developers"
    echo "  $0 researchers project_alpha"
    exit 1
fi

GROUP_NAME="$1"
TENANT="${2:-${AWS_DEFAULT_TENANT:-sils_mns}}"

# Save original profile and force use of default for IAM operations
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

POLICY_NAME="default-s3-access"

# Create policy document
POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListAllMyBuckets"
      ],
      "Resource": [
        "arn:aws:s3::${TENANT}:",
        "arn:aws:s3::${TENANT}:*"
      ]
    }
  ]
}
EOF
)

echo "Creating default S3 access policy for group: $GROUP_NAME"
echo "Tenant: $TENANT"
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
    echo "  Group can list all buckets in tenant: $TENANT"
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
