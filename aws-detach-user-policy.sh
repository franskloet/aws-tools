#!/bin/bash
# Script to detach IAM policy from user

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <username> <policy-arn> [profile]"
    echo ""
    echo "Arguments:"
    echo "  username   - IAM username"
    echo "  policy-arn - ARN of the policy to detach"
    echo "  profile    - Optional: AWS profile to use (default: default)"
    echo ""
    echo "Examples:"
    echo "  $0 john arn:aws:iam::aws:policy/AmazonS3FullAccess"
    echo "  $0 jane arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess myprofile"
    exit 1
fi

USERNAME="$1"
POLICY_ARN="$2"
PROFILE="${3:-default}"

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

echo "Detaching policy from user: $USERNAME"
echo "Policy ARN: $POLICY_ARN"
echo ""

# Detach the policy
if aws iam detach-user-policy --user-name "$USERNAME" --policy-arn "$POLICY_ARN"; then
    echo ""
    echo "✓ Policy detached from user $USERNAME"
else
    echo ""
    echo "✗ Failed to detach policy from user"
    exit 1
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
