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

# Quick alias to show current AWS profile
alias aws-current='echo "Current AWS Profile: ${AWS_PROFILE:-default}"'

# Alias to list all AWS profiles
alias aws-profiles='echo "Available AWS profiles:" && grep "^\[profile " ~/.aws/config 2>/dev/null | sed "s/^\[profile \(.*\)\]/  - \1/" && [ -f ~/.aws/credentials ] && grep "^\[default\]" ~/.aws/credentials &>/dev/null && echo "  - default"'

# Alias to show current AWS identity
alias aws-whoami='aws sts get-caller-identity'

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
    echo "Attached policies for user $1:"
    aws iam list-attached-user-policies --user-name "$1"
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
echo "  aws-whoami                            - Show current AWS identity"
echo "  aws-attach-policy <user> <arn>       - Attach policy to user"
echo "  aws-list-user-policies <user>        - List user's policies"
