#!/bin/bash
# Script to detach IAM policy from group

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <group-name> <policy-arn> [profile]"
    echo ""
    echo "Arguments:"
    echo "  group-name - IAM group name"
    echo "  policy-arn - ARN of the policy to detach"
    echo "  profile    - Optional: AWS profile to use (default: default)"
    echo ""
    echo "Examples:"
    echo "  $0 developers arn:aws:iam::aws:policy/AmazonS3FullAccess"
    echo "  $0 analysts arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess myprofile"
    exit 1
fi

GROUP_NAME="$1"
POLICY_ARN="$2"
PROFILE="${3:-default}"

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

echo "Detaching policy from group: $GROUP_NAME"
echo "Policy ARN: $POLICY_ARN"
echo ""

# Detach the policy
if aws iam detach-group-policy --group-name "$GROUP_NAME" --policy-arn "$POLICY_ARN"; then
    echo ""
    echo "✓ Policy detached from group $GROUP_NAME"
else
    echo ""
    echo "✗ Failed to detach policy from group"
    exit 1
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
