#!/bin/bash
# AWS Add User to Group Script
# Usage: ./aws-add-user-to-group.sh <username> <group-name>

set -e

USERNAME="$1"
GROUP_NAME="$2"

if [ -z "$USERNAME" ] || [ -z "$GROUP_NAME" ]; then
    echo "Usage: $0 <username> <group-name>"
    echo "  username: IAM username"
    echo "  group-name: IAM group name"
    exit 1
fi

# Save current profile and use default for IAM operations
ORIG_AWS_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

echo "Adding user '$USERNAME' to group '$GROUP_NAME'..."
aws iam add-user-to-group --user-name "$USERNAME" --group-name "$GROUP_NAME"

# Restore original profile
if [ -n "$ORIG_AWS_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_AWS_PROFILE"
else
    unset AWS_PROFILE
fi

echo "✓ User '$USERNAME' added to group '$GROUP_NAME'"
