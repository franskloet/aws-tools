#!/bin/bash
# Script to remove all policies from a user

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <username> [profile]"
    echo ""
    echo "Arguments:"
    echo "  username - IAM username"
    echo "  profile  - Optional: AWS profile to use (default: default)"
    echo ""
    echo "WARNING: This will remove ALL policies (both managed and inline) from the user"
    echo ""
    echo "Examples:"
    echo "  $0 john"
    echo "  $0 jane myprofile"
    exit 1
fi

USERNAME="$1"
PROFILE="${2:-default}"

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

echo "Clearing all policies from user: $USERNAME"
echo ""

# Get all attached managed policies
MANAGED_POLICIES=$(aws iam list-attached-user-policies --user-name "$USERNAME" --output json 2>/dev/null | jq -r '.AttachedPolicies[].PolicyArn')

if [ -n "$MANAGED_POLICIES" ]; then
    echo "Detaching managed policies..."
    while IFS= read -r policy_arn; do
        echo "  - Detaching: $policy_arn"
        aws iam detach-user-policy --user-name "$USERNAME" --policy-arn "$policy_arn"
    done <<< "$MANAGED_POLICIES"
    echo ""
else
    echo "No managed policies found"
    echo ""
fi

# Get all inline policies
INLINE_POLICIES=$(aws iam list-user-policies --user-name "$USERNAME" --output json 2>/dev/null | jq -r '.PolicyNames[]')

if [ -n "$INLINE_POLICIES" ]; then
    echo "Deleting inline policies..."
    while IFS= read -r policy_name; do
        echo "  - Deleting: $policy_name"
        aws iam delete-user-policy --user-name "$USERNAME" --policy-name "$policy_name"
    done <<< "$INLINE_POLICIES"
    echo ""
else
    echo "No inline policies found"
    echo ""
fi

echo "✓ All policies removed from user: $USERNAME"

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
