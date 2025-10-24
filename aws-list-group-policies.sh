#!/bin/bash
# Script to list inline policies attached to a group

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <group-name> [profile]"
    echo ""
    echo "Arguments:"
    echo "  group-name - IAM group name"
    echo "  profile    - Optional: AWS profile to use (default: default)"
    echo ""
    echo "This lists inline policies (created with aws-attach-group-bucket-policy)"
    echo "For managed policies, use: aws iam list-attached-group-policies --group-name <group>"
    echo ""
    echo "Examples:"
    echo "  $0 data-scientists"
    echo "  $0 developers myprofile"
    exit 1
fi

GROUP_NAME="$1"
PROFILE="${2:-default}"

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

echo "Inline policies for group: $GROUP_NAME"
echo ""

# List inline policies
POLICIES=$(aws iam list-group-policies --group-name "$GROUP_NAME" --output json 2>/dev/null | jq -r '.PolicyNames[]')

if [ -z "$POLICIES" ]; then
    echo "  No inline policies found"
else
    echo "$POLICIES" | while read -r policy; do
        echo "Policy: $policy"
        echo "---"
        aws iam get-group-policy --group-name "$GROUP_NAME" --policy-name "$policy" --output json | jq -r '.PolicyDocument | @json' | jq '.'
        echo ""
    done
fi

echo ""
echo "Managed (attached) policies for group: $GROUP_NAME"
echo ""

# List attached managed policies
aws iam list-attached-group-policies --group-name "$GROUP_NAME" --output json 2>/dev/null | jq -r '.AttachedPolicies[] | "  - \(.PolicyName): \(.PolicyArn)"'

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
