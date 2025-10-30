#!/bin/bash
# AWS User Policy Attachment Script
# Attaches an inline policy to an IAM user
# Usage: ./aws-attach-user-policy.sh <username> <policy-name> <policy-document-file|-> [profile]

set -e

USERNAME="$1"
POLICY_NAME="$2"
POLICY_SOURCE="$3"
PROFILE="${4:-default}"

if [ -z "$USERNAME" ] || [ -z "$POLICY_NAME" ] || [ -z "$POLICY_SOURCE" ]; then
    echo "Usage: $0 <username> <policy-name> <policy-document-file|-> [profile]"
    echo ""
    echo "Arguments:"
    echo "  username              - IAM username"
    echo "  policy-name           - Name for the inline policy"
    echo "  policy-document-file  - Path to JSON policy document, or '-' for stdin"
    echo "  profile               - Optional: AWS profile to use (default: default)"
    echo ""
    echo "Examples:"
    echo "  # From file"
    echo "  $0 john-doe s3-read-policy policy.json"
    echo ""
    echo "  # From stdin"
    echo "  cat policy.json | $0 john-doe s3-read-policy -"
    echo ""
    echo "  # Inline JSON"
    echo "  echo '{\"Version\":\"2012-10-17\",\"Statement\":[...]}' | $0 john-doe policy -"
    exit 1
fi

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

# Read policy document
if [ "$POLICY_SOURCE" = "-" ]; then
    echo "Reading policy document from stdin..."
    POLICY_DOCUMENT=$(cat)
else
    if [ ! -f "$POLICY_SOURCE" ]; then
        echo "Error: Policy file not found: $POLICY_SOURCE"
        exit 1
    fi
    echo "Reading policy document from: $POLICY_SOURCE"
    POLICY_DOCUMENT=$(cat "$POLICY_SOURCE")
fi

# Validate JSON
if ! echo "$POLICY_DOCUMENT" | jq empty 2>/dev/null; then
    echo "Error: Policy document is not valid JSON"
    exit 1
fi

echo ""
echo "Attaching inline policy to user: $USERNAME"
echo "Policy name: $POLICY_NAME"
echo ""

# Check if user exists
if ! aws iam get-user --user-name "$USERNAME" &>/dev/null; then
    echo "Error: User '$USERNAME' does not exist"
    exit 1
fi

# Attach the policy
if aws iam put-user-policy \
    --user-name "$USERNAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOCUMENT"; then
    echo ""
    echo "✓ Policy '$POLICY_NAME' attached to user '$USERNAME'"
else
    echo ""
    echo "✗ Failed to attach policy"
    exit 1
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi

echo ""
echo "To view user policies, run:"
echo "  ./aws-list-user-policies.sh $USERNAME"
