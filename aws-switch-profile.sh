#!/bin/bash
# AWS Profile Switcher
# Usage: source ./aws-switch-profile.sh <profile-name>
#   or:  aws-switch-profile <profile-name>

PROFILE_NAME="$1"

if [ -z "$PROFILE_NAME" ]; then
    echo "Available AWS profiles:"
    echo ""
    
    # List profiles from config file
    if [ -f "$HOME/.aws/config" ]; then
        grep '^\[profile ' "$HOME/.aws/config" | sed 's/^\[profile \(.*\)\]/  - \1/'
    fi
    
    # List default profile from credentials
    if [ -f "$HOME/.aws/credentials" ]; then
        if grep -q '^\[default\]' "$HOME/.aws/credentials"; then
            echo "  - default"
        fi
    fi
    
    echo ""
    echo "Current profile: ${AWS_PROFILE:-default}"
    echo ""
    echo "Usage: source $0 <profile-name>"
    echo "   or: aws-switch-profile <profile-name>"
    return 0 2>/dev/null || exit 0
fi

# Check if profile exists
AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
AWS_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"

PROFILE_EXISTS=0
if grep -q "^\[profile $PROFILE_NAME\]" "$AWS_CONFIG_FILE" 2>/dev/null || \
   grep -q "^\[$PROFILE_NAME\]" "$AWS_CREDENTIALS_FILE" 2>/dev/null; then
    PROFILE_EXISTS=1
fi

if [ $PROFILE_EXISTS -eq 0 ]; then
    echo "Error: Profile '$PROFILE_NAME' not found in AWS configuration"
    return 1 2>/dev/null || exit 1
fi

export AWS_PROFILE="$PROFILE_NAME"
echo "✓ Switched to AWS profile: $PROFILE_NAME"

# Verify by testing S3 access (better for Ceph endpoints)
if command -v aws &> /dev/null; then
    echo ""
    if aws s3 ls 2>/dev/null >/dev/null; then
        echo "✓ Credentials verified - S3 access confirmed"
    else
        echo "Note: Could not verify S3 access (credentials may need policies attached)"
    fi
fi
