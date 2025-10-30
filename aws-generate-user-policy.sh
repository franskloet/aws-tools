#!/bin/bash
# AWS User Policy Generator
# Generates common IAM policy templates for users
# Usage: ./aws-generate-user-policy.sh <policy-type> <username> [bucket-name]

set -e

POLICY_TYPE="$1"
USERNAME="$2"
BUCKET_NAME="$3"

if [ -z "$POLICY_TYPE" ] || [ -z "$USERNAME" ]; then
    echo "Usage: $0 <policy-type> <username> [bucket-name]"
    echo ""
    echo "Policy Types:"
    echo "  s3-full-access        - Full S3 access to all buckets"
    echo "  s3-read-only          - Read-only S3 access to all buckets"
    echo "  s3-bucket-full        - Full access to specific bucket (requires bucket-name)"
    echo "  s3-bucket-read        - Read-only access to specific bucket (requires bucket-name)"
    echo "  s3-user-folder        - Access to user's folder in bucket (requires bucket-name)"
    echo "  custom                - Output template for custom policy"
    echo ""
    echo "Examples:"
    echo "  # Generate and attach full S3 access"
    echo "  $0 s3-full-access john-doe | ./aws-attach-user-policy.sh john-doe s3-full-access -"
    echo ""
    echo "  # Generate and save bucket-specific policy"
    echo "  $0 s3-bucket-full john-doe my-bucket > policy.json"
    echo ""
    echo "  # Generate user folder policy"
    echo "  $0 s3-user-folder alice shared-bucket | ./aws-attach-user-policy.sh alice folder-access -"
    exit 1
fi

case "$POLICY_TYPE" in
    s3-full-access)
        cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
EOF
        ;;
    
    s3-read-only)
        cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket",
        "s3:ListBucketVersions"
      ],
      "Resource": "*"
    }
  ]
}
EOF
        ;;
    
    s3-bucket-full)
        if [ -z "$BUCKET_NAME" ]; then
            echo "Error: bucket-name required for s3-bucket-full policy" >&2
            exit 1
        fi
        cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF
        ;;
    
    s3-bucket-read)
        if [ -z "$BUCKET_NAME" ]; then
            echo "Error: bucket-name required for s3-bucket-read policy" >&2
            exit 1
        fi
        cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF
        ;;
    
    s3-user-folder)
        if [ -z "$BUCKET_NAME" ]; then
            echo "Error: bucket-name required for s3-user-folder policy" >&2
            exit 1
        fi
        cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "users/${USERNAME}/*",
            "shared/*",
            "users/${USERNAME}",
            "shared"
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
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}/users/${USERNAME}/*",
        "arn:aws:s3:::${BUCKET_NAME}/shared/*"
      ]
    }
  ]
}
EOF
        ;;
    
    custom)
        cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CustomPolicy",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name"
      ]
    },
    {
      "Sid": "CustomObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }
  ]
}
EOF
        ;;
    
    *)
        echo "Error: Unknown policy type: $POLICY_TYPE" >&2
        echo "Run '$0' without arguments to see available types" >&2
        exit 1
        ;;
esac
