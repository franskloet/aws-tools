#!/bin/bash
# Script to remove all policies from a group

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <group-name> [profile]"
    echo ""
    echo "Arguments:"
    echo "  group-name - IAM group name"
    echo "  profile    - Optional: AWS profile to use (default: default)"
    echo ""
    echo "WARNING: This will remove ALL policies (both managed and inline) from the group"
    echo ""
    echo "Examples:"
    echo "  $0 developers"
    echo "  $0 analysts myprofile"
    exit 1
fi

GROUP_NAME="$1"
PROFILE="${2:-default}"

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

echo "Clearing all policies from group: $GROUP_NAME"
echo ""

# Get all attached managed policies
MANAGED_POLICIES=$(aws iam list-attached-group-policies --group-name "$GROUP_NAME" --output json 2>/dev/null | jq -r '.AttachedPolicies[].PolicyArn')

if [ -n "$MANAGED_POLICIES" ]; then
    echo "Detaching managed policies..."
    while IFS= read -r policy_arn; do
        echo "  - Detaching: $policy_arn"
        aws iam detach-group-policy --group-name "$GROUP_NAME" --policy-arn "$policy_arn"
    done <<< "$MANAGED_POLICIES"
    echo ""
else
    echo "No managed policies found"
    echo ""
fi

# Get all inline policies
INLINE_POLICIES=$(aws iam list-group-policies --group-name "$GROUP_NAME" --output json 2>/dev/null | jq -r '.PolicyNames[]')

if [ -n "$INLINE_POLICIES" ]; then
    echo "Deleting inline policies..."
    while IFS= read -r policy_name; do
        echo "  - Deleting: $policy_name"
        aws iam delete-group-policy --group-name "$GROUP_NAME" --policy-name "$policy_name"
    done <<< "$INLINE_POLICIES"
    echo ""
else
    echo "No inline policies found"
    echo ""
fi

echo "✓ All policies removed from group: $GROUP_NAME"

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
