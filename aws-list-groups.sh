#!/bin/bash
# AWS List Groups Script
# Usage: ./aws-list-groups.sh [group-name]

GROUP_NAME="$1"

# Save current profile and use default for IAM operations
ORIG_AWS_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

if [ -z "$GROUP_NAME" ]; then
    # List all groups
    echo "IAM Groups:"
    echo ""
    aws iam list-groups --output json | jq -r '.Groups[] | "  - \(.GroupName) (created: \(.CreateDate))"'
else
    # Show specific group details
    echo "Group: $GROUP_NAME"
    echo ""
    
    # Show group policies
    echo "Attached Policies:"
    aws iam list-attached-group-policies --group-name "$GROUP_NAME" --output json | jq -r '.AttachedPolicies[] | "  - \(.PolicyName): \(.PolicyArn)"'
    
    echo ""
    echo "Members:"
    aws iam get-group --group-name "$GROUP_NAME" --output json | jq -r '.Users[] | "  - \(.UserName)"'
fi

# Restore original profile
if [ -n "$ORIG_AWS_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_AWS_PROFILE"
else
    unset AWS_PROFILE
fi
