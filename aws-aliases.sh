#!/bin/bash
# AWS Management Aliases and Functions
# Add to your ~/.bashrc: export AWS_SCRIPTS_DIR="/path/to/aws-tools" && source "$AWS_SCRIPTS_DIR/aws-aliases.sh"

# Directory where AWS scripts are located (must be set before sourcing this file)
if [ -z "$AWS_SCRIPTS_DIR" ]; then
    echo "Error: AWS_SCRIPTS_DIR is not set. Please set it before sourcing this file."
    echo "Example: export AWS_SCRIPTS_DIR=\"$HOME/Development/storage/aws-tools\""
    return 1 2>/dev/null || exit 1
fi

# Alias to create new AWS user
alias aws-create-user="$AWS_SCRIPTS_DIR/aws-create-user.sh"

# Alias to delete AWS user
alias aws-delete-user="$AWS_SCRIPTS_DIR/aws-delete-user.sh"

# Function to switch AWS profile (must be sourced)
aws-switch-profile() {
    source "$AWS_SCRIPTS_DIR/aws-switch-profile.sh" "$@"
}

# Alias to create group policy (default S3 access)
alias aws-create-group-policy="$AWS_SCRIPTS_DIR/aws-create-group-policy.sh"

# Alias to create user policy (bucket/prefix access)
alias aws-create-user-policy="$AWS_SCRIPTS_DIR/aws-create-user-policy.sh"

# Aliases for group management
alias aws-create-group="$AWS_SCRIPTS_DIR/aws-create-group.sh"
alias aws-add-user-to-group="$AWS_SCRIPTS_DIR/aws-add-user-to-group.sh"
alias aws-list-groups="$AWS_SCRIPTS_DIR/aws-list-groups.sh"
alias aws-detach-user-policy="$AWS_SCRIPTS_DIR/aws-detach-user-policy.sh"
alias aws-detach-group-policy="$AWS_SCRIPTS_DIR/aws-detach-group-policy.sh"
alias aws-list-group-policies="$AWS_SCRIPTS_DIR/aws-list-group-policies.sh"
alias aws-clear-user-policies="$AWS_SCRIPTS_DIR/aws-clear-user-policies.sh"
alias aws-clear-group-policies="$AWS_SCRIPTS_DIR/aws-clear-group-policies.sh"
alias aws-restrict-group-to-bucket="$AWS_SCRIPTS_DIR/aws-restrict-group-to-bucket.sh"

# Quick alias to show current AWS profile
alias aws-current='echo "Current AWS Profile: ${AWS_PROFILE:-default}"'

# Alias to list all AWS profiles
alias aws-profiles='echo "Available AWS profiles:" && grep "^\[profile " ~/.aws/config 2>/dev/null | sed "s/^\[profile \(.*\)\]/  - \1/" && [ -f ~/.aws/credentials ] && grep "^\[default\]" ~/.aws/credentials &>/dev/null && echo "  - default"'

# Function to show current AWS identity (Ceph-compatible)
aws-whoami() {
    echo "Current AWS Profile: ${AWS_PROFILE:-default}"
    echo ""
    
    # Try STS first (works for real AWS)
    if aws sts get-caller-identity 2>/dev/null; then
        return 0
    fi
    
    # Fallback for Ceph/S3-compatible endpoints
    echo "STS not available (Ceph/S3-compatible endpoint)"
    echo "Testing S3 access..."
    echo ""
    
    # First try listing all buckets (for users with broad access)
    if aws s3 ls 2>/dev/null >/dev/null; then
        echo "✓ S3 access confirmed (can list all buckets)"
        echo "  Profile: ${AWS_PROFILE:-default}"
    else
        # User may have bucket-specific access only
        echo "⚠ Cannot list all buckets (may have bucket-specific access only)"
        echo "  Profile: ${AWS_PROFILE:-default}"
        echo ""
        echo "Note: This profile may have access to specific buckets only."
        echo "      Use 'aws s3 ls s3://<bucket-name>' to test bucket access."
    fi
    
    # Show config details
    if [ -f "$HOME/.aws/config" ]; then
        local PROFILE_SECTION="${AWS_PROFILE:-default}"
        if [ "$PROFILE_SECTION" != "default" ]; then
            PROFILE_SECTION="profile $PROFILE_SECTION"
        fi
        echo ""
        echo "Configuration:"
        grep -A 5 "^\[$PROFILE_SECTION\]" "$HOME/.aws/config" 2>/dev/null | grep -E "(endpoint_url|region)" | sed 's/^/  /'
    fi
}

# Function to quickly attach policy to user
aws-attach-policy() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: aws-attach-policy <username> <policy-arn|policy-name>"
        echo "Common policies:"
        echo "  AmazonS3FullAccess or arn:aws:iam::aws:policy/AmazonS3FullAccess"
        echo "  AmazonS3ReadOnlyAccess or arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
        return 1
    fi
    local ORIG_PROFILE="${AWS_PROFILE:-}"
    export AWS_PROFILE=default
    
    # Auto-prefix policy ARN if not already an ARN
    local POLICY_ARN="$2"
    if [[ ! "$POLICY_ARN" =~ ^arn: ]]; then
        POLICY_ARN="arn:aws:iam::aws:policy/$POLICY_ARN"
    fi
    
    aws iam attach-user-policy --user-name "$1" --policy-arn "$POLICY_ARN"
    echo "✓ Policy attached to user $1"
    if [ -n "$ORIG_PROFILE" ]; then
        export AWS_PROFILE="$ORIG_PROFILE"
    else
        unset AWS_PROFILE
    fi
}

# Function to list user policies
aws-list-user-policies() {
    if [ -z "$1" ]; then
        echo "Usage: aws-list-user-policies <username>"
        return 1
    fi
    local ORIG_PROFILE="${AWS_PROFILE:-}"
    export AWS_PROFILE=default
    echo "Attached policies for user $1:"
    aws iam list-attached-user-policies --user-name "$1"
    if [ -n "$ORIG_PROFILE" ]; then
        export AWS_PROFILE="$ORIG_PROFILE"
    else
        unset AWS_PROFILE
    fi
}

# Function to attach policy to group
aws-attach-group-policy() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: aws-attach-group-policy <group-name> <policy-arn|policy-name>"
        echo "Common policies:"
        echo "  AmazonS3FullAccess or arn:aws:iam::aws:policy/AmazonS3FullAccess"
        echo "  AmazonS3ReadOnlyAccess or arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
        return 1
    fi
    local ORIG_PROFILE="${AWS_PROFILE:-}"
    export AWS_PROFILE=default
    
    # Auto-prefix policy ARN if not already an ARN
    local POLICY_ARN="$2"
    if [[ ! "$POLICY_ARN" =~ ^arn: ]]; then
        POLICY_ARN="arn:aws:iam::aws:policy/$POLICY_ARN"
    fi
    
    aws iam attach-group-policy --group-name "$1" --policy-arn "$POLICY_ARN"
    echo "✓ Policy attached to group $1"
    if [ -n "$ORIG_PROFILE" ]; then
        export AWS_PROFILE="$ORIG_PROFILE"
    else
        unset AWS_PROFILE
    fi
}

# Display available commands
aws-commands() {
echo "AWS management tools loaded!"
echo "Available commands:"
echo "  aws-create-user <username> [profile]  - Create IAM user and configure profile"
echo "  aws-delete-user <username> [profile]  - Delete IAM user and remove profile"
echo "  aws-switch-profile <profile>          - Switch to different AWS profile"
echo "  aws-current                           - Show current AWS profile"
echo "  aws-profiles                          - List all configured profiles"
echo "  aws-whoami                            - Show current AWS identity"
echo "  aws-attach-policy <user> <arn|name>  - Attach policy to user"
echo "  aws-detach-user-policy <user> <arn>  - Detach policy from user"
echo "  aws-clear-user-policies <user>       - Remove all policies from user"
echo "  aws-list-user-policies <user>        - List user's policies"
echo "  aws-create-group <group> [arn]       - Create IAM group with optional policy"
echo "  aws-attach-group-policy <group> <arn|name> - Attach policy to group"
echo "  aws-detach-group-policy <group> <arn> - Detach policy from group"
echo "  aws-clear-group-policies <group>     - Remove all policies from group"
echo "  aws-create-group-policy <group> [tenant] - Create default S3 policy for group"
echo "  aws-create-user-policy <user> <bucket> [prefixes] [tenant] - Create bucket/prefix policy for user"
echo "  aws-list-group-policies <group>      - List all policies for a group"
echo "  aws-add-user-to-group <user> <group> - Add user to group"
echo "  aws-list-groups [group]              - List all groups or group details"
}

# Show available commands only once per day
AWS_ALIASES_LOCK="$HOME/.aws-aliases-shown"
if [ ! -f "$AWS_ALIASES_LOCK" ] || [ "$(find "$AWS_ALIASES_LOCK" -mtime +0 2>/dev/null)" ]; then
    aws-commands
    touch "$AWS_ALIASES_LOCK"
fi
