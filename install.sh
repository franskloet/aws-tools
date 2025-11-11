#!/bin/bash
# Installation script for AWS Management Tools

set -e

# Check if target directory is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <target-directory>"
    echo "Example: $0 ~/s3/AWS"
    exit 1
fi

TARGET_DIR="$1"

# Expand tilde if present
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    echo "Creating directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing AWS tools to: $TARGET_DIR"
echo ""

# List of scripts to copy
SCRIPTS=(
    "aws-add-user-to-group.sh"
    "aws-attach-user-policy.sh"
    "aws-clear-group-policies.sh"
    "aws-clear-user-policies.sh"
    "aws-create-group.sh"
    "aws-create-group-policy.sh"
    "aws-create-user.sh"
    "aws-create-user-policy.sh"
    "aws-delete-user.sh"
    "aws-detach-group-policy.sh"
    "aws-detach-user-policy.sh"
    "aws-generate-user-policy.sh"
    "aws-list-group-policies.sh"
    "aws-list-groups.sh"
    "aws-remove-user-inline-policy.sh"
    "aws-switch-profile.sh"
)

# Copy all scripts
echo "Copying scripts..."
for script in "${SCRIPTS[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        cp "$SCRIPT_DIR/$script" "$TARGET_DIR/"
        chmod +x "$TARGET_DIR/$script"
        echo "  ✓ $script"
    else
        echo "  ⚠ Warning: $script not found"
    fi
done

# Copy and modify aws-aliases.sh
echo ""
echo "Installing aws-aliases.sh with updated path..."
if [ -f "$SCRIPT_DIR/aws-aliases.sh" ]; then
    sed "s|AWS_SCRIPTS_DIR=\"\$HOME/s3/AWS\"|AWS_SCRIPTS_DIR=\"$TARGET_DIR\"|" \
        "$SCRIPT_DIR/aws-aliases.sh" > "$TARGET_DIR/aws-aliases.sh"
    chmod +x "$TARGET_DIR/aws-aliases.sh"
    echo "  ✓ aws-aliases.sh"
else
    echo "  ✗ Error: aws-aliases.sh not found"
    exit 1
fi

echo ""
echo "Installation complete!"
echo ""
echo "To use these tools, add the following line to your ~/.bashrc:"
echo "  source $TARGET_DIR/aws-aliases.sh"
echo ""
echo "Then reload your shell with: source ~/.bashrc"
