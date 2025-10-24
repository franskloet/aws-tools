#!/bin/bash
# AWS Group Creation Script
# Usage: ./aws-create-group.sh <group-name> [policy-arn]

set -e

GROUP_NAME="$1"
POLICY_ARN="$2"

if [ -z "$GROUP_NAME" ]; then
    echo "Usage: $0 <group-name> [policy-arn]"
    echo "  group-name: IAM group name to create"
    echo "  policy-arn: Optional policy ARN to attach to the group"
    echo ""
    echo "Common policies:"
    echo "  arn:aws:iam::aws:policy/AmazonS3FullAccess"
    echo "  arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    exit 1
fi

# Save current profile and use default for IAM operations
ORIG_AWS_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

# Check if group already exists
echo "Checking if group exists: $GROUP_NAME"
if aws iam get-group --group-name "$GROUP_NAME" &>/dev/null; then
    echo "Group '$GROUP_NAME' already exists"
else
    echo "Creating IAM group: $GROUP_NAME"
    aws iam create-group --group-name "$GROUP_NAME"
    echo "✓ Group created"
fi

# Attach policy if provided
if [ -n "$POLICY_ARN" ]; then
    echo ""
    echo "Attaching policy to group..."
    aws iam attach-group-policy --group-name "$GROUP_NAME" --policy-arn "$POLICY_ARN"
    echo "✓ Policy attached: $POLICY_ARN"
fi

# Restore original profile
if [ -n "$ORIG_AWS_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_AWS_PROFILE"
else
    unset AWS_PROFILE
fi

echo ""
echo "✓ Group '$GROUP_NAME' ready"
echo ""
echo "To add users to this group, run:"
echo "  aws-add-user-to-group <username> $GROUP_NAME"
