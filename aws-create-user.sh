#!/bin/bash
# AWS User Creation and Configuration Script
# Usage: ./aws-create-user.sh <username> [profile-name]

set -e

USERNAME="$1"
PROFILE_NAME="${2:-$USERNAME}"

if [ -z "$USERNAME" ]; then
    echo "Usage: $0 <username> [profile-name]"
    echo "  username: AWS IAM username to create"
    echo "  profile-name: AWS CLI profile name (defaults to username)"
    exit 1
fi

AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
AWS_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"

# Ensure AWS config directory exists
mkdir -p "$(dirname "$AWS_CONFIG_FILE")"
mkdir -p "$(dirname "$AWS_CREDENTIALS_FILE")"

# Save current profile and use default for IAM operations
ORIG_AWS_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

# Check if user already exists
echo "Checking if user exists: $USERNAME"
if aws iam get-user --user-name "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' already exists"
    
    # In non-interactive mode (AUTO_CONFIRM=1), automatically create new key
    if [ "${AUTO_CONFIRM:-0}" = "1" ]; then
        echo "Auto-confirming: Creating new access key for existing user"
    else
        read -p "Create new access key for existing user? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted. User exists but no new access key created."
            exit 1
        fi
    fi
else
    echo "Creating IAM user: $USERNAME"
    aws iam create-user --user-name "$USERNAME"
fi

echo "Creating access key for user: $USERNAME"
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$USERNAME" --output json)

ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')

if [ -z "$ACCESS_KEY_ID" ] || [ -z "$SECRET_ACCESS_KEY" ]; then
    echo "Error: Failed to extract access keys"
    exit 1
fi

echo ""
echo "Adding profile '$PROFILE_NAME' to AWS configuration..."

# Add to credentials file
if ! grep -q "^\[$PROFILE_NAME\]" "$AWS_CREDENTIALS_FILE" 2>/dev/null; then
    cat >> "$AWS_CREDENTIALS_FILE" << EOF

[$PROFILE_NAME]
aws_access_key_id = $ACCESS_KEY_ID
aws_secret_access_key = $SECRET_ACCESS_KEY
EOF
    echo "Added credentials to $AWS_CREDENTIALS_FILE"
else
    echo "Warning: Profile '$PROFILE_NAME' already exists in credentials file"
fi

# Add to config file
if ! grep -q "^\[profile $PROFILE_NAME\]" "$AWS_CONFIG_FILE" 2>/dev/null; then
    # Get endpoint_url from default profile if it exists
    ENDPOINT_URL=$(grep -A 10 '^\[default\]' "$AWS_CONFIG_FILE" 2>/dev/null | grep '^endpoint_url' | head -1 | sed 's/endpoint_url *= *//')
    
    {
        echo ""
        echo "[profile $PROFILE_NAME]"
        echo "region = us-east-1"
        echo "output = json"
        
        # Add endpoint_url if it was found in default profile
        if [ -n "$ENDPOINT_URL" ]; then
            echo "endpoint_url = $ENDPOINT_URL"
        fi
    } >> "$AWS_CONFIG_FILE"
    
    if [ -n "$ENDPOINT_URL" ]; then
        echo "Copied endpoint_url from default profile: $ENDPOINT_URL"
    fi
    
    echo "Added profile to $AWS_CONFIG_FILE"
else
    echo "Warning: Profile '$PROFILE_NAME' already exists in config file"
fi

# Restore original profile
if [ -n "$ORIG_AWS_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_AWS_PROFILE"
else
    unset AWS_PROFILE
fi

echo ""
echo "✓ User '$USERNAME' created successfully!"
echo "✓ Profile '$PROFILE_NAME' configured"
echo ""
echo "To use this profile, run:"
echo "  export AWS_PROFILE=$PROFILE_NAME"
echo "  or use: aws-switch-profile $PROFILE_NAME"
echo ""
echo "Access Key ID: $ACCESS_KEY_ID"
echo "Secret Access Key: [hidden - saved in $AWS_CREDENTIALS_FILE]"
