#!/bin/bash
# Script to list which groups have inline policies for a specific bucket

set -o pipefail

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <bucket-name>"
    echo ""
    echo "Arguments:"
    echo "  bucket-name - S3 bucket name"
    echo ""
    echo "This lists all groups with inline policies granting access to the specified bucket"
    echo ""
    echo "Note: This script always uses the 'default' AWS profile for IAM operations."
    echo ""
    echo "Examples:"
    echo "  $0 my-bucket"
    echo "  $0 project-x-bucket"
    exit 1
fi

BUCKET_NAME="$1"

# Save original profile and force use of default for IAM operations
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

echo "Groups with policies for bucket: $BUCKET_NAME"
echo ""

# Use temp files to avoid bash/jq quirks with command substitution
TEMP_GROUPS="$(mktemp)"
trap "rm -f '$TEMP_GROUPS'" EXIT

# Get all groups
aws iam list-groups --output json | jq -r '.Groups[] | .GroupName' > "$TEMP_GROUPS"
if [ ! -s "$TEMP_GROUPS" ]; then
    echo "  No groups found"
    exit 0
fi

FOUND=0
while IFS= read -r group; do
    [ -z "$group" ] && continue
    
    # List inline policies for this group
    POLICIES=$(aws iam list-group-policies --group-name "$group" --output json | jq -r '.PolicyNames[] | .' 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$POLICIES" ]; then
        while IFS= read -r policy; do
            [ -z "$policy" ] && continue
            
            # Check if policy name contains the bucket name
            if [[ "$policy" == *"$BUCKET_NAME"* ]]; then
                FOUND=1
                echo "Group: $group"
                echo "  Policy: $policy"
                
                # Extract access level from policy name
                if [[ "$policy" == *"-full" ]]; then
                    ACCESS_LEVEL="full"
                elif [[ "$policy" == *"-read" ]]; then
                    ACCESS_LEVEL="read-only"
                elif [[ "$policy" == *"-write" ]]; then
                    ACCESS_LEVEL="write-only"
                else
                    ACCESS_LEVEL="custom"
                fi
                
                echo "  Access: $ACCESS_LEVEL"
                echo ""
            fi
        done <<< "$POLICIES"
    fi
done < "$TEMP_GROUPS"

if [ $FOUND -eq 0 ]; then
    echo "  No groups found with policies for bucket: $BUCKET_NAME"
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
