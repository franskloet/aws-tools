#!/bin/bash
# AWS User Inline Policy Removal Script
# Removes an inline policy from an IAM user
# Usage: ./aws-remove-user-inline-policy.sh <username> <policy-name> [profile]

set -e

USERNAME="$1"
POLICY_NAME="$2"
PROFILE="${3:-default}"

if [ -z "$USERNAME" ] || [ -z "$POLICY_NAME" ]; then
    echo "Usage: $0 <username> <policy-name> [profile]"
    echo ""
    echo "Arguments:"
    echo "  username     - IAM username"
    echo "  policy-name  - Name of the inline policy to remove"
    echo "  profile      - Optional: AWS profile to use (default: default)"
    echo ""
    echo "Examples:"
    echo "  $0 john-doe s3-read-policy"
    echo "  $0 alice bucket-access default"
    echo ""
    echo "To list user policies first, run:"
    echo "  ./aws-list-user-policies.sh <username>"
    echo ""
    echo "Note: This removes INLINE policies (created with put-user-policy)."
    echo "      To detach MANAGED policies, use: ./aws-detach-user-policy.sh"
    exit 1
fi

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

echo "Removing inline policy from user: $USERNAME"
echo "Policy name: $POLICY_NAME"
echo ""

# Check if user exists
if ! aws iam get-user --user-name "$USERNAME" &>/dev/null; then
    echo "Error: User '$USERNAME' does not exist"
    exit 1
fi

# Check if policy exists
if ! aws iam get-user-policy --user-name "$USERNAME" --policy-name "$POLICY_NAME" &>/dev/null; then
    echo "Error: Inline policy '$POLICY_NAME' not found on user '$USERNAME'"
    echo ""
    echo "Available inline policies for $USERNAME:"
    aws iam list-user-policies --user-name "$USERNAME" --output json | jq -r '.PolicyNames[]' 2>/dev/null || echo "  (none)"
    exit 1
fi

# Show policy before deletion
echo "Policy to be removed:"
aws iam get-user-policy --user-name "$USERNAME" --policy-name "$POLICY_NAME" --output json 2>/dev/null | jq -r '.PolicyDocument | fromjson' || echo "(unable to display)"
echo ""

read -p "Are you sure you want to remove this policy? (yes/N) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Remove the policy
if aws iam delete-user-policy \
    --user-name "$USERNAME" \
    --policy-name "$POLICY_NAME"; then
    echo ""
    echo "✓ Inline policy '$POLICY_NAME' removed from user '$USERNAME'"
else
    echo ""
    echo "✗ Failed to remove policy"
    exit 1
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi

echo ""
echo "To view remaining policies, run:"
echo "  ./aws-list-user-policies.sh $USERNAME"
