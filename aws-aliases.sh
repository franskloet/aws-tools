#!/bin/bash
# AWS Management Aliases and Functions
# Add to your ~/.bashrc: source ~/s3/AWS/aws-aliases.sh

# Directory where AWS scripts are located
AWS_SCRIPTS_DIR="$HOME/s3/AWS"

# Alias to create new AWS user
alias aws-create-user="$AWS_SCRIPTS_DIR/aws-create-user.sh"

# Alias to delete AWS user
alias aws-delete-user="$AWS_SCRIPTS_DIR/aws-delete-user.sh"

# Function to switch AWS profile (must be sourced)
aws-switch-profile() {
    source "$AWS_SCRIPTS_DIR/aws-switch-profile.sh" "$@"
}

# Alias to create bucket policies
alias aws-bucket-policy="$AWS_SCRIPTS_DIR/aws-create-bucket-policy.sh"

# Alias to get bucket policy
alias aws-get-bucket-policy="$AWS_SCRIPTS_DIR/aws-get-bucket-policy.sh"

# Aliases for group management
alias aws-create-group="$AWS_SCRIPTS_DIR/aws-create-group.sh"
alias aws-add-user-to-group="$AWS_SCRIPTS_DIR/aws-add-user-to-group.sh"
alias aws-list-groups="$AWS_SCRIPTS_DIR/aws-list-groups.sh"
alias aws-attach-group-bucket-policy="$AWS_SCRIPTS_DIR/aws-attach-group-bucket-policy.sh"
alias aws-detach-user-policy="$AWS_SCRIPTS_DIR/aws-detach-user-policy.sh"
alias aws-detach-group-policy="$AWS_SCRIPTS_DIR/aws-detach-group-policy.sh"
alias aws-detach-group-bucket-policy="$AWS_SCRIPTS_DIR/aws-detach-group-bucket-policy.sh"

# Quick alias to show current AWS profile
alias aws-current='echo "Current AWS Profile: ${AWS_PROFILE:-default}"'

# Alias to list all AWS profiles
alias aws-profiles='echo "Available AWS profiles:" && grep "^\[profile " ~/.aws/config 2>/dev/null | sed "s/^\[profile \(.*\)\]/  - \1/" && [ -f ~/.aws/credentials ] && grep "^\[default\]" ~/.aws/credentials &>/dev/null && echo "  - default"'

# Function to show current AWS identity (Ceph-compatible)
aws_whoami() {
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
    
    if aws s3 ls 2>/dev/null >/dev/null; then
        echo "✓ S3 access confirmed with profile: ${AWS_PROFILE:-default}"
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
    else
        echo "✗ S3 access denied or credentials invalid"
        return 1
    fi
}

# Function to quickly attach policy to user
aws-attach-policy() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: aws-attach-policy <username> <policy-arn>"
        echo "Common policies:"
        echo "  AmazonS3FullAccess: arn:aws:iam::aws:policy/AmazonS3FullAccess"
        echo "  AmazonS3ReadOnlyAccess: arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
        return 1
    fi
    local ORIG_PROFILE="${AWS_PROFILE:-}"
    export AWS_PROFILE=default
    aws iam attach-user-policy --user-name "$1" --policy-arn "$2"
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
        echo "Usage: aws-attach-group-policy <group-name> <policy-arn>"
        echo "Common policies:"
        echo "  AmazonS3FullAccess: arn:aws:iam::aws:policy/AmazonS3FullAccess"
        echo "  AmazonS3ReadOnlyAccess: arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
        return 1
    fi
    local ORIG_PROFILE="${AWS_PROFILE:-}"
    export AWS_PROFILE=default
    aws iam attach-group-policy --group-name "$1" --policy-arn "$2"
    echo "✓ Policy attached to group $1"
    if [ -n "$ORIG_PROFILE" ]; then
        export AWS_PROFILE="$ORIG_PROFILE"
    else
        unset AWS_PROFILE
    fi
}

echo "AWS management tools loaded!"
echo "Available commands:"
echo "  aws-create-user <username> [profile]  - Create IAM user and configure profile"
echo "  aws-delete-user <username> [profile]  - Delete IAM user and remove profile"
echo "  aws-switch-profile <profile>          - Switch to different AWS profile"
echo "  aws-bucket-policy <bucket> <type>     - Create and apply S3 bucket policy"
echo "  aws-get-bucket-policy <bucket>        - Get current bucket policy"
echo "  aws-current                           - Show current AWS profile"
echo "  aws-profiles                          - List all configured profiles"
echo "  aws_whoami                            - Show current AWS identity"
echo "  aws-attach-policy <user> <arn>       - Attach policy to user"
echo "  aws-detach-user-policy <user> <arn>  - Detach policy from user"
echo "  aws-list-user-policies <user>        - List user's policies"
echo "  aws-create-group <group> [arn]       - Create IAM group with optional policy"
echo "  aws-attach-group-policy <group> <arn> - Attach policy to group"
echo "  aws-detach-group-policy <group> <arn> - Detach policy from group"
echo "  aws-attach-group-bucket-policy <group> <bucket> [level] - Attach bucket policy to group"
echo "  aws-detach-group-bucket-policy <group> <bucket> [level] - Detach bucket policy from group"
echo "  aws-add-user-to-group <user> <group> - Add user to group"
echo "  aws-list-groups [group]              - List all groups or group details"
