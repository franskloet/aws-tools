#!/bin/bash
# Script to grant bucket access to IAM group users via bucket policy (CEPH compatible)

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <group-name> <bucket-name> [access-level] [profile]"
    echo ""
    echo "Arguments:"
    echo "  group-name    - IAM group name"
    echo "  bucket-name   - S3 bucket name"
    echo "  access-level  - Optional: full, read, write (default: full)"
    echo "  profile       - Optional: AWS profile to use (default: default)"
    echo ""
    echo "Examples:"
    echo "  $0 developers project-x-bucket write"
    exit 1
fi

GROUP_NAME="$1"
BUCKET_NAME="$2"
ACCESS_LEVEL="${3:-full}"
PROFILE="${4:-default}"

# Save original profile
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE="$PROFILE"

# Get all users in the group
echo "Getting users in group: $GROUP_NAME"
USERS=$(aws iam get-group --group-name "$GROUP_NAME" --query 'Users[*].UserName' --output text 2>&1)

if [ $? -ne 0 ]; then
    echo "✗ Failed to get group members: $USERS"
    exit 1
fi

if [ -z "$USERS" ]; then
    echo "✗ No users found in group: $GROUP_NAME"
    exit 1
fi

# Get account ID (or use a placeholder for CEPH)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "ceph")

# Build array of user ARNs
USER_ARNS=""
for user in $USERS; do
    if [ -n "$USER_ARNS" ]; then
        USER_ARNS="$USER_ARNS,"
    fi
    USER_ARNS="$USER_ARNS\"arn:aws:iam::${ACCOUNT_ID}:user/${user}\""
done

# Define actions based on access level
case "$ACCESS_LEVEL" in
    full)
        ACTIONS='"s3:*"'
        ;;
    read)
        ACTIONS='"s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"'
        ;;
    write)
        ACTIONS='"s3:PutObject", "s3:PutObjectAcl", "s3:DeleteObject"'
        ;;
    *)
        echo "Error: Invalid access level. Use: full, read, or write"
        exit 1
        ;;
esac

# Get existing bucket policy (if any)
EXISTING_POLICY=$(aws s3api get-bucket-policy --bucket "$BUCKET_NAME" --query Policy --output text 2>/dev/null)

# Create new statement
STATEMENT_ID="GroupAccess-${GROUP_NAME}-${ACCESS_LEVEL}"
NEW_STATEMENT=$(cat <<EOF
    {
      "Sid": "$STATEMENT_ID",
      "Effect": "Allow",
      "Principal": {
        "AWS": [$USER_ARNS]
      },
      "Action": [$ACTIONS],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
EOF
)

# Build complete policy
if [ -n "$EXISTING_POLICY" ] && [ "$EXISTING_POLICY" != "None" ]; then
    # Remove existing statement with same Sid and add new one
    POLICY_DOCUMENT=$(echo "$EXISTING_POLICY" | python3 -c "
import json, sys
policy = json.load(sys.stdin)
# Remove any existing statement with same Sid
policy['Statement'] = [s for s in policy['Statement'] if s.get('Sid') != '$STATEMENT_ID']
# Add new statement
policy['Statement'].append($NEW_STATEMENT)
print(json.dumps(policy))
")
else
    # Create new policy
    POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
$NEW_STATEMENT
  ]
}
EOF
)
fi

echo ""
echo "Granting $ACCESS_LEVEL access to bucket: $BUCKET_NAME"
echo "For group: $GROUP_NAME (users: $USERS)"
echo ""

# Apply bucket policy
if aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy "$POLICY_DOCUMENT"; then
    echo ""
    echo "✓ Bucket policy updated successfully"
    echo "  Group '$GROUP_NAME' members now have $ACCESS_LEVEL access to: $BUCKET_NAME"
else
    echo ""
    echo "✗ Failed to update bucket policy"
    exit 1
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
