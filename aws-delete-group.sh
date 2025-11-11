#!/bin/bash
# AWS Group Deletion Script
# Usage: ./aws-delete-group.sh <group-name>

set -e

GROUP_NAME="$1"

if [ -z "$GROUP_NAME" ]; then
    echo "Usage: $0 <group-name>"
    echo "  group-name: IAM group name to delete"
    exit 1
fi

# Prevent deletion of default group if you have one
if [ "$GROUP_NAME" = "default" ]; then
    echo "ERROR: Cannot delete the 'default' group"
    echo "This group is protected from deletion"
    exit 1
fi

echo "WARNING: This will delete IAM group '$GROUP_NAME'"
read -p "Are you sure? (yes/N) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Save current profile and use default for IAM operations
ORIG_AWS_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

# Check if group exists
echo ""
echo "Checking if group exists..."
GROUP_EXISTS=true
if ! aws iam get-group --group-name "$GROUP_NAME" &>/dev/null; then
    echo "ERROR: Group '$GROUP_NAME' does not exist in AWS IAM"
    exit 1
fi
echo "✓ Group '$GROUP_NAME' found"

echo ""
echo "Step 1: Removing users from group..."
# List and remove all users from the group
GROUP_USERS=$(aws iam get-group --group-name "$GROUP_NAME" --output json 2>/dev/null || echo '{"Users":[]}')
USER_COUNT=$(echo "$GROUP_USERS" | jq -r '.Users | length')

if [ "$USER_COUNT" -gt 0 ]; then
    echo "Found $USER_COUNT user(s) in group"
    echo "$GROUP_USERS" | jq -r '.Users[].UserName' | while read -r USER_NAME; do
        echo "  Removing user: $USER_NAME"
        aws iam remove-user-from-group --group-name "$GROUP_NAME" --user-name "$USER_NAME"
    done
else
    echo "No users in group"
fi

echo ""
echo "Step 2: Detaching managed policies..."
# List and detach all attached managed policies
ATTACHED_POLICIES=$(aws iam list-attached-group-policies --group-name "$GROUP_NAME" --output json 2>/dev/null || echo '{"AttachedPolicies":[]}')
POLICY_COUNT=$(echo "$ATTACHED_POLICIES" | jq -r '.AttachedPolicies | length')

if [ "$POLICY_COUNT" -gt 0 ]; then
    echo "Found $POLICY_COUNT attached policy/policies"
    echo "$ATTACHED_POLICIES" | jq -r '.AttachedPolicies[].PolicyArn' | while read -r POLICY_ARN; do
        echo "  Detaching policy: $POLICY_ARN"
        aws iam detach-group-policy --group-name "$GROUP_NAME" --policy-arn "$POLICY_ARN"
    done
else
    echo "No attached policies found"
fi

echo ""
echo "Step 3: Deleting inline policies..."
# List and delete all inline policies
INLINE_POLICIES=$(aws iam list-group-policies --group-name "$GROUP_NAME" --output json 2>/dev/null || echo '{"PolicyNames":[]}')
INLINE_COUNT=$(echo "$INLINE_POLICIES" | jq -r '.PolicyNames | length')

if [ "$INLINE_COUNT" -gt 0 ]; then
    echo "Found $INLINE_COUNT inline policy/policies"
    echo "$INLINE_POLICIES" | jq -r '.PolicyNames[]' | while read -r POLICY_NAME; do
        echo "  Deleting inline policy: $POLICY_NAME"
        aws iam delete-group-policy --group-name "$GROUP_NAME" --policy-name "$POLICY_NAME"
    done
else
    echo "No inline policies found"
fi

echo ""
echo "Step 4: Deleting IAM group..."
aws iam delete-group --group-name "$GROUP_NAME"
echo "✓ IAM group '$GROUP_NAME' deleted"

# Restore original profile
if [ -n "$ORIG_AWS_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_AWS_PROFILE"
else
    unset AWS_PROFILE
fi

echo ""
echo "✓ Group '$GROUP_NAME' completely removed!"
