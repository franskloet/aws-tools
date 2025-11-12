#!/bin/bash
# AWS User Creation and Configuration Script
# Usage: ./aws-create-user.sh [OPTIONS] <username> [profile-name]

set -e

FORCE_KEY=0

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force-key)
            FORCE_KEY=1
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: $0 [OPTIONS] <username> [profile-name]"
            echo "Options:"
            echo "  -f, --force-key    Create new access key even if user exists"
            echo "Arguments:"
            echo "  username           AWS IAM username to create"
            echo "  profile-name       AWS CLI profile name (defaults to username)"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

USERNAME="$1"
PROFILE_NAME="${2:-$USERNAME}"

if [ -z "$USERNAME" ]; then
    echo "Usage: $0 [OPTIONS] <username> [profile-name]"
    echo "Options:"
    echo "  -f, --force-key    Create new access key even if user exists"
    echo "Arguments:"
    echo "  username           AWS IAM username to create"
    echo "  profile-name       AWS CLI profile name (defaults to username)"
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
USER_EXISTS=0
echo "Checking if user exists: $USERNAME"
if aws iam get-user --user-name "$USERNAME" &>/dev/null; then
    USER_EXISTS=1
    echo "User '$USERNAME' already exists"
    
    # Only create new access key if --force-key flag is set
    if [ "$FORCE_KEY" = "1" ]; then
        echo "--force-key flag set: Creating new access key for existing user"
        CREATE_KEY=1
    else
        echo "User already exists. Use --force-key flag to create a new access key."
        CREATE_KEY=0
    fi
    
    if [ "$CREATE_KEY" = "1" ]; then
        # Delete all existing access keys for this user
        echo "Checking for existing access keys..."
        EXISTING_KEYS=$(aws iam list-access-keys --user-name "$USERNAME" --output json | jq -r '.AccessKeyMetadata[].AccessKeyId')
        
        if [ -n "$EXISTING_KEYS" ]; then
            echo "Deleting existing access keys..."
            while IFS= read -r key_id; do
                if [ -n "$key_id" ]; then
                    echo "  Deleting access key: $key_id"
                    aws iam delete-access-key --user-name "$USERNAME" --access-key-id "$key_id"
                fi
            done <<< "$EXISTING_KEYS"
        fi
    fi
else
    echo "Creating IAM user: $USERNAME"
    aws iam create-user --user-name "$USERNAME"
    CREATE_KEY=1
fi

if [ "$CREATE_KEY" = "1" ]; then
    echo "Creating access key for user: $USERNAME"
    ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$USERNAME" --output json)
else
    echo "Skipping access key creation. User already exists."
    
    # Restore original profile and exit
    if [ -n "$ORIG_AWS_PROFILE" ]; then
        export AWS_PROFILE="$ORIG_AWS_PROFILE"
    else
        unset AWS_PROFILE
    fi
    
    echo ""
    echo "✓ User '$USERNAME' already exists"
    echo "✓ No new access key created"
    echo ""
    echo "To create a new access key, run:"
    echo "  $0 --force-key $USERNAME"
    exit 0
fi

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
    echo "Updating existing profile '$PROFILE_NAME' in credentials file"
    # Use sed to update the access key and secret key in the existing profile
    sed -i "/^\[$PROFILE_NAME\]/,/^\[/s|^aws_access_key_id = .*|aws_access_key_id = $ACCESS_KEY_ID|" "$AWS_CREDENTIALS_FILE"
    sed -i "/^\[$PROFILE_NAME\]/,/^\[/s|^aws_secret_access_key = .*|aws_secret_access_key = $SECRET_ACCESS_KEY|" "$AWS_CREDENTIALS_FILE"
    echo "Updated credentials in $AWS_CREDENTIALS_FILE"
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
