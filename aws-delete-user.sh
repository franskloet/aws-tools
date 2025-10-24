#!/bin/bash
# AWS User Deletion Script
# Usage: ./aws-delete-user.sh <username> [profile-name]

set -e

USERNAME="$1"
PROFILE_NAME="${2:-$USERNAME}"

if [ -z "$USERNAME" ]; then
    echo "Usage: $0 <username> [profile-name]"
    echo "  username: AWS IAM username to delete"
    echo "  profile-name: AWS CLI profile name to remove (defaults to username)"
    exit 1
fi

AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
AWS_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"

echo "WARNING: This will delete IAM user '$USERNAME' and remove profile '$PROFILE_NAME'"
read -p "Are you sure? (yes/N) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Save current profile and use default for IAM operations
ORIG_AWS_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

echo ""
echo "Step 1: Listing and deleting access keys..."
# List and delete all access keys for the user
ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USERNAME" --output json 2>/dev/null || echo '{"AccessKeyMetadata":[]}')
KEY_COUNT=$(echo "$ACCESS_KEYS" | jq -r '.AccessKeyMetadata | length')

if [ "$KEY_COUNT" -gt 0 ]; then
    echo "Found $KEY_COUNT access key(s) for user $USERNAME"
    echo "$ACCESS_KEYS" | jq -r '.AccessKeyMetadata[].AccessKeyId' | while read -r KEY_ID; do
        echo "  Deleting access key: $KEY_ID"
        aws iam delete-access-key --user-name "$USERNAME" --access-key-id "$KEY_ID"
    done
else
    echo "No access keys found for user $USERNAME"
fi

echo ""
echo "Step 2: Detaching user policies..."
# List and detach all attached policies
ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "$USERNAME" --output json 2>/dev/null || echo '{"AttachedPolicies":[]}')
POLICY_COUNT=$(echo "$ATTACHED_POLICIES" | jq -r '.AttachedPolicies | length')

if [ "$POLICY_COUNT" -gt 0 ]; then
    echo "Found $POLICY_COUNT attached policy/policies"
    echo "$ATTACHED_POLICIES" | jq -r '.AttachedPolicies[].PolicyArn' | while read -r POLICY_ARN; do
        echo "  Detaching policy: $POLICY_ARN"
        aws iam detach-user-policy --user-name "$USERNAME" --policy-arn "$POLICY_ARN"
    done
else
    echo "No attached policies found"
fi

# Delete inline policies if any
echo ""
echo "Step 3: Deleting inline policies..."
INLINE_POLICIES=$(aws iam list-user-policies --user-name "$USERNAME" --output json 2>/dev/null || echo '{"PolicyNames":[]}')
INLINE_COUNT=$(echo "$INLINE_POLICIES" | jq -r '.PolicyNames | length')

if [ "$INLINE_COUNT" -gt 0 ]; then
    echo "Found $INLINE_COUNT inline policy/policies"
    echo "$INLINE_POLICIES" | jq -r '.PolicyNames[]' | while read -r POLICY_NAME; do
        echo "  Deleting inline policy: $POLICY_NAME"
        aws iam delete-user-policy --user-name "$USERNAME" --policy-name "$POLICY_NAME"
    done
else
    echo "No inline policies found"
fi

# Remove user from groups
echo ""
echo "Step 4: Removing user from groups..."
USER_GROUPS=$(aws iam list-groups-for-user --user-name "$USERNAME" --output json 2>/dev/null || echo '{"Groups":[]}')
GROUP_COUNT=$(echo "$USER_GROUPS" | jq -r '.Groups | length')

if [ "$GROUP_COUNT" -gt 0 ]; then
    echo "Found $GROUP_COUNT group(s)"
    echo "$USER_GROUPS" | jq -r '.Groups[].GroupName' | while read -r GROUP_NAME; do
        echo "  Removing from group: $GROUP_NAME"
        aws iam remove-user-from-group --user-name "$USERNAME" --group-name "$GROUP_NAME"
    done
else
    echo "User is not in any groups"
fi

echo ""
echo "Step 5: Deleting IAM user..."
aws iam delete-user --user-name "$USERNAME"
echo "✓ IAM user '$USERNAME' deleted"

# Remove from AWS config file
echo ""
echo "Step 6: Removing profile from AWS configuration..."
if [ -f "$AWS_CONFIG_FILE" ] && grep -q "^\[profile $PROFILE_NAME\]" "$AWS_CONFIG_FILE"; then
    # Use sed to remove the profile section and all lines until the next section or EOF
    sed -i "/^\[profile $PROFILE_NAME\]/,/^\[/{ /^\[profile $PROFILE_NAME\]/d; /^\[/!d; }" "$AWS_CONFIG_FILE"
    echo "✓ Removed profile from $AWS_CONFIG_FILE"
else
    echo "Profile not found in config file"
fi

# Remove from AWS credentials file
if [ -f "$AWS_CREDENTIALS_FILE" ] && grep -q "^\[$PROFILE_NAME\]" "$AWS_CREDENTIALS_FILE"; then
    # Use sed to remove the credentials section and all lines until the next section or EOF
    sed -i "/^\[$PROFILE_NAME\]/,/^\[/{ /^\[$PROFILE_NAME\]/d; /^\[/!d; }" "$AWS_CREDENTIALS_FILE"
    echo "✓ Removed credentials from $AWS_CREDENTIALS_FILE"
else
    echo "Profile not found in credentials file"
fi

# Restore original profile
if [ -n "$ORIG_AWS_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_AWS_PROFILE"
else
    unset AWS_PROFILE
fi

echo ""
echo "✓ User '$USERNAME' and profile '$PROFILE_NAME' completely removed!"
