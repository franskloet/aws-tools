#!/bin/bash
# Script to create per-user folder access policy
# Grants a user access to their own folder and a shared folder in a bucket

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <username> <bucket-name> [shared-folder]"
    echo ""
    echo "Arguments:"
    echo "  username      - IAM username"
    echo "  bucket-name   - S3 bucket name"
    echo "  shared-folder - Optional: shared folder path (default: shared)"
    echo ""
    echo "This creates a policy that grants the user:"
    echo "  - Full access to <bucket>/users/<username>/*"
    echo "  - Full access to <bucket>/<shared-folder>/*"
    echo "  - List access restricted to these folders only"
    echo ""
    echo "Note: This script always uses the 'default' AWS profile for IAM operations."
    echo ""
    echo "Examples:"
    echo "  $0 john-doe my-bucket"
    echo "  $0 alice project-bucket shared-files"
    exit 1
fi

USERNAME="$1"
BUCKET_NAME="$2"
SHARED_FOLDER="${3:-shared}"

# Save original profile and force use of default for IAM operations
ORIG_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

POLICY_NAME="${USERNAME}-${BUCKET_NAME}-folder-access"

# Create policy document
POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "users/${USERNAME}/*",
            "users/${USERNAME}",
            "${SHARED_FOLDER}/*",
            "${SHARED_FOLDER}"
          ]
        }
      }
    },
    {
      "Sid": "AllowUserFolderAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}/users/${USERNAME}/*",
        "arn:aws:s3:::${BUCKET_NAME}/${SHARED_FOLDER}/*"
      ]
    }
  ]
}
EOF
)

echo "Creating per-user folder policy for: $USERNAME"
echo "Bucket: $BUCKET_NAME"
echo "User folder: users/$USERNAME/"
echo "Shared folder: $SHARED_FOLDER/"
echo ""

# Apply the policy
if aws iam put-user-policy \
    --user-name "$USERNAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOCUMENT"; then
    echo ""
    echo "✓ Policy '$POLICY_NAME' applied to user '$USERNAME'"
    echo "  User has access to:"
    echo "    - s3://$BUCKET_NAME/users/$USERNAME/"
    echo "    - s3://$BUCKET_NAME/$SHARED_FOLDER/"
    echo ""
    echo "  User can list only these prefixes in the bucket"
else
    echo ""
    echo "✗ Failed to apply policy to user"
    exit 1
fi

# Restore original profile
if [ -n "$ORIG_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_PROFILE"
else
    unset AWS_PROFILE
fi
