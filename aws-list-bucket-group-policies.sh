#!/bin/bash
# Script to list which groups have inline policies for a specific bucket

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <bucket-name> [profile]"
    echo ""
    echo "Arguments:"
    echo "  bucket-name - S3 bucket name"
    echo "  profile     - Optional: AWS profile to use (default: default)"
    echo ""
    echo "This lists all groups with inline policies granting access to the specified bucket"
    echo ""
    echo "Examples:"
    echo "  $0 my-bucket"
    echo "  $0 data-bucket myprofile"
    exit 1
fi

BUCKET_NAME="$1"
PROFILE="${2:-default}"

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

echo "Groups with policies for bucket: $BUCKET_NAME"
echo ""

# Get all groups
GROUPS=$(aws iam list-groups --output json 2>/dev/null | jq -r '.Groups[].GroupName')

if [ -z "$GROUPS" ]; then
    echo "  No groups found"
else
    FOUND=0
    while IFS= read -r group; do
        # List inline policies for this group
        POLICIES=$(aws iam list-group-policies --group-name "$group" --output json 2>/dev/null | jq -r '.PolicyNames[]')
        
        if [ -n "$POLICIES" ]; then
            while IFS= read -r policy; do
                # Check if policy name contains the bucket name
                if [[ "$policy" == *"$BUCKET_NAME"* ]]; then
                    FOUND=1
                    echo "Group: $group"
                    echo "  Policy: $policy"
                    
                    # Get policy details
                    POLICY_DOC=$(aws iam get-group-policy --group-name "$group" --policy-name "$policy" --output json 2>/dev/null | jq -r '.PolicyDocument')
                    
                    # Extract access level from policy name or actions
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
    done <<< "$GROUPS"
    
    if [ $FOUND -eq 0 ]; then
        echo "  No groups found with policies for bucket: $BUCKET_NAME"
    fi
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
