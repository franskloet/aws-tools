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
    aws iam list-groups --output json | jq -r '.Groups[] | "  - \(.GroupName)" + (if .CreateDate then " (created: \(.CreateDate))" else "" end)'
else
    # Show group members
    echo "Members of group: $GROUP_NAME"
    echo ""
    
    MEMBERS=$(aws iam get-group --group-name "$GROUP_NAME" --output json 2>/dev/null | jq -r '.Users[].UserName')
    
    if [ -n "$MEMBERS" ]; then
        while IFS= read -r member; do
            echo "  - $member"
        done <<< "$MEMBERS"
    else
        echo "  (no members)"
    fi
fi

# Restore original profile
if [ -n "$ORIG_AWS_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_AWS_PROFILE"
else
    unset AWS_PROFILE
fi
